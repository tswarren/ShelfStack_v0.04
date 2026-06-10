# frozen_string_literal: true

module Seeds
  module Phase2ClassificationTax
    TAX_CATEGORIES = [
      { name: "Non-Taxable", short_name: "Non-Tax", sort_order: 10 },
      { name: "Books", short_name: "Books", sort_order: 20 },
      { name: "Periodicals", short_name: "Periodicals", sort_order: 30 },
      { name: "General Merchandise", short_name: "Merch", sort_order: 40 },
      { name: "Prepared Food", short_name: "Food", sort_order: 50 },
      { name: "Gift Card", short_name: "Gift Card", sort_order: 60 }
    ].freeze

    STORE_TAXABLE_BPS = {
      "001" => 600,
      "002" => 950
    }.freeze

    STORE_TAX_MAPPINGS = {
      "001" => {
        "Non-Taxable" => "Non-Taxable",
        "Books" => "Non-Taxable",
        "Periodicals" => "Taxable",
        "General Merchandise" => "Taxable",
        "Prepared Food" => "Taxable",
        "Gift Card" => "Non-Taxable"
      },
      "002" => {
        "Non-Taxable" => "Non-Taxable",
        "Books" => "Taxable",
        "Periodicals" => "Taxable",
        "General Merchandise" => "Taxable",
        "Prepared Food" => "Taxable",
        "Gift Card" => "Non-Taxable"
      }
    }.freeze

    EFFECTIVE_ON = Date.new(2026, 1, 1)

    DEPARTMENTS = [
      { department_number: "001", name: "Books", short_name: "Books", gl_account_code: "4000" },
      { department_number: "002", name: "Periodicals", short_name: "Periodicals", gl_account_code: "4010" },
      { department_number: "003", name: "Sidelines", short_name: "Sidelines", gl_account_code: "4020" },
      { department_number: "004", name: "Used Books", short_name: "Used Books", gl_account_code: "4030" },
      { department_number: "005", name: "Gift Cards", short_name: "Gift Cards", gl_account_code: "2100" },
      { department_number: "006", name: "Food & Beverage", short_name: "Food/Bev", gl_account_code: "4040" }
    ].freeze

    CATEGORIES = {
      "001" => [
        { name: "Hardcover", short_name: "Hardcover", default_pricing_model: "trade_discount",
          default_margin_target_bps: 4000, default_supplier_discount_bps: 4600, tax_category: "Books" },
        { name: "Trade Paperback", short_name: "Trade Paper", default_pricing_model: "trade_discount",
          default_margin_target_bps: 4000, default_supplier_discount_bps: 4600, tax_category: "Books" },
        { name: "Mass Market Paperback", short_name: "Mass Market", default_pricing_model: "trade_discount",
          default_margin_target_bps: 4000, default_supplier_discount_bps: 4600, tax_category: "Books" },
        { name: "Children's Books", short_name: "Children", default_pricing_model: "trade_discount",
          default_margin_target_bps: 4000, default_supplier_discount_bps: 4600, tax_category: "Books" }
      ],
      "002" => [
        { name: "Magazines", short_name: "Magazines", default_pricing_model: "trade_discount",
          default_margin_target_bps: 3500, default_supplier_discount_bps: 3500, tax_category: "Periodicals" },
        { name: "Newspapers", short_name: "Newspapers", default_pricing_model: "trade_discount",
          default_margin_target_bps: 2500, default_supplier_discount_bps: 2500, tax_category: "Periodicals" }
      ],
      "003" => [
        { name: "Gifts", short_name: "Gifts", default_pricing_model: "net_cost_markup",
          default_margin_target_bps: 5000, default_supplier_discount_bps: nil, tax_category: "General Merchandise" },
        { name: "Stationery", short_name: "Stationery", default_pricing_model: "net_cost_markup",
          default_margin_target_bps: 5000, default_supplier_discount_bps: nil, tax_category: "General Merchandise" },
        { name: "Games & Puzzles", short_name: "Games", default_pricing_model: "net_cost_markup",
          default_margin_target_bps: 5000, default_supplier_discount_bps: nil, tax_category: "General Merchandise" }
      ],
      "004" => [
        { name: "Used Hardcover", short_name: "Used HC", default_pricing_model: "buyback_resale",
          default_margin_target_bps: 6000, default_supplier_discount_bps: nil, tax_category: "Books" },
        { name: "Used Paperback", short_name: "Used PB", default_pricing_model: "buyback_resale",
          default_margin_target_bps: 6000, default_supplier_discount_bps: nil, tax_category: "Books" }
      ],
      "005" => [
        { name: "Gift Cards", short_name: "Gift Cards", default_pricing_model: "pass_through",
          default_margin_target_bps: 0, default_supplier_discount_bps: nil, tax_category: "Gift Card" }
      ],
      "006" => [
        { name: "Prepared Beverages", short_name: "Beverages", default_pricing_model: "net_cost_markup",
          default_margin_target_bps: 6000, default_supplier_discount_bps: nil, tax_category: "Prepared Food" },
        { name: "Packaged Snacks", short_name: "Snacks", default_pricing_model: "net_cost_markup",
          default_margin_target_bps: 5000, default_supplier_discount_bps: nil, tax_category: "Prepared Food" }
      ]
    }.freeze

    module_function

    def seed!
      seed_tax_categories!
      seed_store_tax_rates!
      seed_store_tax_category_rates!
      seed_departments!
      seed_categories!
    end

    def seed_tax_categories!
      TAX_CATEGORIES.each do |attrs|
        TaxCategory.find_or_initialize_by(name: attrs[:name]).tap do |tax_category|
          tax_category.short_name = attrs[:short_name]
          tax_category.sort_order = attrs[:sort_order]
          tax_category.active = true
          tax_category.save!
        end
      end
    end

    def seed_store_tax_rates!
      Store.find_each do |store|
        bps = STORE_TAXABLE_BPS.fetch(store.store_number, 600)

        [
          { name: "Non-Taxable", short_name: "Non-Tax", tax_identifier: "N", tax_rate_bps: 0 },
          { name: "Taxable", short_name: "Taxable", tax_identifier: "T", tax_rate_bps: bps }
        ].each do |attrs|
          StoreTaxRate.find_or_initialize_by(store: store, name: attrs[:name]).tap do |rate|
            rate.short_name = attrs[:short_name]
            rate.tax_identifier = attrs[:tax_identifier]
            rate.tax_rate_bps = attrs[:tax_rate_bps]
            rate.active = true
            rate.save!
          end
        end
      end
    end

    def seed_store_tax_category_rates!
      tax_categories_by_name = TaxCategory.all.index_by(&:name)

      Store.find_each do |store|
        mappings = STORE_TAX_MAPPINGS.fetch(store.store_number, STORE_TAX_MAPPINGS["001"])
        rates_by_name = store.store_tax_rates.index_by(&:name)

        mappings.each do |tax_category_name, rate_name|
          tax_category = tax_categories_by_name.fetch(tax_category_name)
          store_tax_rate = rates_by_name.fetch(rate_name)

          StoreTaxCategoryRate.find_or_initialize_by(
            store: store,
            tax_category: tax_category,
            effective_on: EFFECTIVE_ON
          ).tap do |mapping|
            mapping.store_tax_rate = store_tax_rate
            mapping.ends_on = nil
            mapping.active = true
            mapping.save!
          end
        end
      end
    end

    def seed_departments!
      DEPARTMENTS.each do |attrs|
        Department.find_or_initialize_by(department_number: attrs[:department_number]).tap do |department|
          department.name = attrs[:name]
          department.short_name = attrs[:short_name]
          department.gl_account_code = attrs[:gl_account_code]
          department.active = true
          department.save!
        end
      end
    end

    def seed_categories!
      tax_categories_by_name = TaxCategory.all.index_by(&:name)

      CATEGORIES.each do |department_number, categories|
        department = Department.find_by!(department_number: department_number)

        categories.each_with_index do |attrs, index|
          Category.find_or_initialize_by(department: department, name: attrs[:name]).tap do |category|
            category.short_name = attrs[:short_name]
            category.sort_order = index
            category.default_pricing_model = attrs[:default_pricing_model]
            category.default_margin_target_bps = attrs[:default_margin_target_bps]
            category.default_supplier_discount_bps = attrs[:default_supplier_discount_bps]
            category.default_tax_category = tax_categories_by_name.fetch(attrs[:tax_category])
            category.active = true
            category.save!
          end
        end
      end
    end
  end
end
