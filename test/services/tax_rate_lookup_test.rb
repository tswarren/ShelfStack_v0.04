# frozen_string_literal: true

require "test_helper"

class TaxRateLookupTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @tax_category = TaxCategory.create!(name: "Books", short_name: "Books", sort_order: 10)
    @non_tax = StoreTaxRate.create!(
      store: @store, name: "Non-Taxable", short_name: "Non-Tax", tax_identifier: "N", tax_rate_bps: 0
    )
    @taxable = StoreTaxRate.create!(
      store: @store, name: "Taxable", short_name: "Taxable", tax_identifier: "T", tax_rate_bps: 600
    )
  end

  test "returns applicable store tax rate" do
    StoreTaxCategoryRate.create!(
      store: @store,
      tax_category: @tax_category,
      store_tax_rate: @non_tax,
      effective_on: Date.new(2026, 1, 1)
    )

    result = TaxRateLookup.call(store: @store, tax_category: @tax_category, date: Date.new(2026, 6, 15))
    assert_equal @non_tax, result
  end

  test "raises MissingRateError when no mapping applies" do
    assert_raises(TaxRateLookup::MissingRateError) do
      TaxRateLookup.call(store: @store, tax_category: @tax_category, date: Date.new(2026, 1, 1))
    end
  end

  test "raises AmbiguousRateError when multiple mappings apply" do
    StoreTaxCategoryRate.create!(
      store: @store,
      tax_category: @tax_category,
      store_tax_rate: @non_tax,
      effective_on: Date.new(2026, 1, 1),
      ends_on: Date.new(2026, 12, 31)
    )
    overlapping = StoreTaxCategoryRate.new(
      store: @store,
      tax_category: @tax_category,
      store_tax_rate: @taxable,
      effective_on: Date.new(2026, 6, 1)
    )
    overlapping.save(validate: false)

    assert_raises(TaxRateLookup::AmbiguousRateError) do
      TaxRateLookup.call(store: @store, tax_category: @tax_category, date: Date.new(2026, 7, 1))
    end
  end

  test "ignores inactive mappings" do
    StoreTaxCategoryRate.create!(
      store: @store,
      tax_category: @tax_category,
      store_tax_rate: @non_tax,
      effective_on: Date.new(2026, 1, 1),
      active: false
    )
    StoreTaxCategoryRate.create!(
      store: @store,
      tax_category: @tax_category,
      store_tax_rate: @taxable,
      effective_on: Date.new(2026, 2, 1)
    )

    result = TaxRateLookup.call(store: @store, tax_category: @tax_category, date: Date.new(2026, 6, 1))
    assert_equal @taxable, result
  end

  test "respects end date boundaries" do
    StoreTaxCategoryRate.create!(
      store: @store,
      tax_category: @tax_category,
      store_tax_rate: @non_tax,
      effective_on: Date.new(2026, 1, 1),
      ends_on: Date.new(2026, 6, 30)
    )

    assert_equal @non_tax,
                 TaxRateLookup.call(store: @store, tax_category: @tax_category, date: Date.new(2026, 6, 30))

    assert_raises(TaxRateLookup::MissingRateError) do
      TaxRateLookup.call(store: @store, tax_category: @tax_category, date: Date.new(2026, 7, 1))
    end
  end
end
