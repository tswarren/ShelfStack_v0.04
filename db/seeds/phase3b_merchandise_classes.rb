# frozen_string_literal: true

module Seeds
  module Phase3bMerchandiseClasses
    MERCHANDISE_CLASSES = [
      {
        merchandise_class_key: "general_trade_books",
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
        merchandise_class_key: "periodicals",
        name: "Periodicals",
        short_name: "Periodicals",
        default_pricing_model: "trade_discount",
        default_margin_target_bps: 3500,
        default_supplier_discount_bps: 3500,
        tax_category: "Periodicals"
      },
      {
        merchandise_class_key: "sidelines",
        name: "Sidelines",
        short_name: "Sidelines",
        default_pricing_model: "net_cost_markup",
        default_margin_target_bps: 5000,
        tax_category: "General Merchandise",
        store_marks_up_from_cost: true
      },
      {
        merchandise_class_key: "used_books",
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
        merchandise_class_key: "cafe",
        name: "Cafe",
        short_name: "Cafe",
        default_pricing_model: "net_cost_markup",
        default_margin_target_bps: 6000,
        tax_category: "Prepared Food",
        has_list_price: false,
        store_marks_up_from_cost: true
      },
      {
        merchandise_class_key: "gift_cards",
        name: "Gift Cards",
        short_name: "Gift Cards",
        default_pricing_model: "pass_through",
        default_margin_target_bps: 0,
        tax_category: "Gift Card",
        has_list_price: false,
        vendor_discounts_from_list_price: false,
        default_sales_account_code: "2100"
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

      MERCHANDISE_CLASSES.each do |attrs|
        MerchandiseClass.find_or_initialize_by(merchandise_class_key: attrs[:merchandise_class_key]).tap do |merchandise_class|
          merchandise_class.name = attrs[:name]
          merchandise_class.short_name = attrs[:short_name]
          merchandise_class.default_pricing_model = attrs[:default_pricing_model]
          merchandise_class.default_margin_target_bps = attrs[:default_margin_target_bps]
          merchandise_class.default_supplier_discount_bps = attrs[:default_supplier_discount_bps]
          merchandise_class.default_tax_category = tax_categories_by_name.fetch(attrs[:tax_category])
          merchandise_class.has_list_price = attrs.fetch(:has_list_price, true)
          merchandise_class.vendor_discounts_from_list_price = attrs.fetch(:vendor_discounts_from_list_price, true)
          merchandise_class.store_marks_up_from_cost = attrs.fetch(:store_marks_up_from_cost, false)
          merchandise_class.vendor_returnable_default = attrs.fetch(:vendor_returnable_default, false)
          merchandise_class.used_sales_allowed = attrs.fetch(:used_sales_allowed, false)
          merchandise_class.buyback_allowed = attrs.fetch(:buyback_allowed, false)
          merchandise_class.default_sales_account_code = attrs[:default_sales_account_code]
          merchandise_class.active = true
          merchandise_class.save!
        end
      end

      backfill_category_merchandise_classes!
    end

    def backfill_category_merchandise_classes!
      return unless Category.column_names.include?("merchandise_class_id")

      classes_by_key = MerchandiseClass.all.index_by(&:merchandise_class_key)

      CATEGORY_CLASS_MAP.each do |category_name, class_key|
        category = Category.find_by(name: category_name)
        next if category.blank?

        merchandise_class = classes_by_key[class_key]
        next if merchandise_class.blank?

        category.update!(merchandise_class: merchandise_class) if category.merchandise_class_id != merchandise_class.id
      end
    end
  end
end
