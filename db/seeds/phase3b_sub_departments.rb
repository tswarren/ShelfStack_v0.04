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
        tax_category: "Books",
        vendor_returnable_default: true,
        buyback_allowed: true
      },
      {
        sub_department_key: "periodicals",
        name: "Periodicals",
        short_name: "Periodicals",
        default_pricing_model: "trade_discount",
        tax_category: "Periodicals"
      },
      {
        sub_department_key: "sidelines",
        name: "Sidelines",
        short_name: "Sidelines",
        default_pricing_model: "net_cost_markup",
        tax_category: "General Merchandise"
      },
      {
        sub_department_key: "used_books",
        name: "Used Books",
        short_name: "Used Books",
        default_pricing_model: "buyback_resale",
        tax_category: "Books",
        buyback_allowed: true
      },
      {
        sub_department_key: "cafe",
        name: "Cafe",
        short_name: "Cafe",
        default_pricing_model: "net_cost_markup",
        tax_category: "Prepared Food"
      },
      {
        sub_department_key: "gift_cards",
        name: "Gift Cards",
        short_name: "Gift Cards",
        default_pricing_model: "pass_through",
        tax_category: "Gift Card"
      }
    ].freeze

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
          sub_department.default_tax_category = tax_categories_by_name.fetch(attrs[:tax_category])
          sub_department.vendor_returnable_default = attrs.fetch(:vendor_returnable_default, false)
          sub_department.buyback_allowed = attrs.fetch(:buyback_allowed, false)
          sub_department.active = true
          sub_department.save!
        end
      end
    end

    def find_or_build_sub_department(canonical_key, attrs)
      aliases = LEGACY_KEY_ALIASES.fetch(canonical_key, [ canonical_key ])
      SubDepartment.where(sub_department_key: aliases).first ||
        SubDepartment.find_by(short_name: attrs[:short_name]) ||
        SubDepartment.find_by(name: attrs[:name]) ||
        SubDepartment.new(sub_department_key: canonical_key)
    end
  end
end
