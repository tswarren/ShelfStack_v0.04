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

    module_function

    def seed!
      seed_tax_categories!
      seed_store_tax_rates!
      seed_store_tax_category_rates!
      seed_departments!
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
  end
end
