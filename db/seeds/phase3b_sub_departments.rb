# frozen_string_literal: true

module Seeds
  module Phase3bSubDepartments
    DEPARTMENT_MAP = {
      "general_trade_books" => "001",
      "periodicals" => "002",
      "sidelines" => "003",
      "used_books" => "004",
      "gift_cards" => "005",
      "cafe" => "006"
    }.freeze

    LEGACY_KEY_ALIASES = {
      "general_trade_books" => %w[books_general_trade general_trade_books],
      "periodicals" => %w[periodicals],
      "sidelines" => %w[sidelines],
      "used_books" => %w[used_books],
      "gift_cards" => %w[gift_cards],
      "cafe" => %w[cafe]
    }.freeze

    MERCHANDISE_CLASSES = [
      {
        sub_department_key: "general_trade_books",
        name: "General Trade Books",
        short_name: "Trade Books",
        default_pricing_model: "trade_discount",
        default_margin_target_bps: 4000,
        default_supplier_discount_bps: 4600,
        tax_category: "Books",
        vendor_returnable_default: true,
        buyback_allowed: true
      },
      {
        sub_department_key: "periodicals",
        name: "Periodicals",
        short_name: "Periodicals",
        default_pricing_model: "trade_discount",
        default_margin_target_bps: 3500,
        default_supplier_discount_bps: 3500,
        tax_category: "Periodicals"
      },
      {
        sub_department_key: "sidelines",
        name: "Sidelines",
        short_name: "Sidelines",
        default_pricing_model: "net_cost_markup",
        default_margin_target_bps: 5000,
        tax_category: "General Merchandise",
        store_marks_up_from_cost: true
      },
      {
        sub_department_key: "used_books",
        name: "Used Books",
        short_name: "Used Books",
        default_pricing_model: "buyback_resale",
        default_margin_target_bps: 6000,
        tax_category: "Books",
        used_sales_allowed: true,
        buyback_allowed: true,
        vendor_discounts_from_list_price: false
      },
      {
        sub_department_key: "cafe",
        name: "Cafe",
        short_name: "Cafe",
        default_pricing_model: "net_cost_markup",
        default_margin_target_bps: 6000,
        tax_category: "Prepared Food",
        has_list_price: false,
        store_marks_up_from_cost: true,
        default_variation_type: "variable",
        default_inventory_behavior: "composite_recipe"
      },
      {
        sub_department_key: "gift_cards",
        name: "Gift Cards",
        short_name: "Gift Cards",
        default_pricing_model: "pass_through",
        default_margin_target_bps: 0,
        tax_category: "Gift Card",
        has_list_price: false,
        vendor_discounts_from_list_price: false,
        default_sales_account_code: "2100",
        default_inventory_behavior: "pure_financial"
      }
    ].freeze

    CATEGORY_CLASS_MAP = {
      "Hardcover" => "general_trade_books",
      "Trade Paperback" => "general_trade_books",
      "Mass Market Paperback" => "general_trade_books",
      "Children's Books" => "general_trade_books",
      "Magazines" => "periodicals",
      "Newspapers" => "periodicals",
      "Gifts" => "sidelines",
      "Stationery" => "sidelines",
      "Games & Puzzles" => "sidelines",
      "Used Hardcover" => "used_books",
      "Used Paperback" => "used_books",
      "Gift Cards" => "gift_cards",
      "Prepared Beverages" => "cafe",
      "Packaged Snacks" => "cafe"
    }.freeze

    module_function

    def seed!
      tax_categories_by_name = TaxCategory.all.index_by(&:name)
      departments_by_number = Department.all.index_by(&:department_number)

      MERCHANDISE_CLASSES.each do |attrs|
        department = departments_by_number.fetch(DEPARTMENT_MAP.fetch(attrs[:sub_department_key]))
        find_or_build_sub_department(attrs[:sub_department_key], attrs).tap do |sub_department|
          sub_department.department = department
          sub_department.sub_department_key = attrs[:sub_department_key]
          sub_department.name = attrs[:name]
          sub_department.short_name = attrs[:short_name]
          sub_department.default_pricing_model = attrs[:default_pricing_model]
          sub_department.default_margin_target_bps = attrs[:default_margin_target_bps]
          sub_department.default_supplier_discount_bps = attrs[:default_supplier_discount_bps]
          sub_department.default_tax_category = tax_categories_by_name.fetch(attrs[:tax_category])
          sub_department.has_list_price = attrs.fetch(:has_list_price, true)
          sub_department.vendor_discounts_from_list_price = attrs.fetch(:vendor_discounts_from_list_price, true)
          sub_department.store_marks_up_from_cost = attrs.fetch(:store_marks_up_from_cost, false)
          sub_department.vendor_returnable_default = attrs.fetch(:vendor_returnable_default, false)
          sub_department.used_sales_allowed = attrs.fetch(:used_sales_allowed, false)
          sub_department.buyback_allowed = attrs.fetch(:buyback_allowed, false)
          sub_department.default_sales_account_code = attrs[:default_sales_account_code]
          sub_department.default_variation_type = attrs.fetch(:default_variation_type, "standard")
          sub_department.default_inventory_behavior = attrs.fetch(:default_inventory_behavior, "standard_physical")
          sub_department.active = true
          sub_department.save!
        end
      end

      backfill_category_sub_departments!
    end

    def find_or_build_sub_department(canonical_key, attrs)
      aliases = LEGACY_KEY_ALIASES.fetch(canonical_key, [ canonical_key ])
      SubDepartment.where(sub_department_key: aliases).first ||
        SubDepartment.find_by(short_name: attrs[:short_name]) ||
        SubDepartment.find_by(name: attrs[:name]) ||
        SubDepartment.new(sub_department_key: canonical_key)
    end

    def backfill_category_sub_departments!
      return unless Category.column_names.include?("sub_department_id")

      classes_by_key = SubDepartment.all.index_by(&:sub_department_key)

      CATEGORY_CLASS_MAP.each do |category_name, class_key|
        category = Category.find_by(name: category_name)
        next if category.blank?

        sub_department = classes_by_key[class_key]
        next if sub_department.blank?

        category.update!(
          sub_department: sub_department,
          department: sub_department.department
        ) if category.sub_department_id != sub_department.id || category.department_id != sub_department.department_id
      end
    end
  end
end
