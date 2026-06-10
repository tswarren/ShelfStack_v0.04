# frozen_string_literal: true

require "test_helper"

class StoreTaxCategoryRateTest < ActiveSupport::TestCase
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

  test "valid mapping" do
    mapping = StoreTaxCategoryRate.new(
      store: @store,
      tax_category: @tax_category,
      store_tax_rate: @non_tax,
      effective_on: Date.new(2026, 1, 1)
    )
    assert mapping.valid?
    assert mapping.save
  end

  test "ends_on must be on or after effective_on" do
    mapping = StoreTaxCategoryRate.new(
      store: @store,
      tax_category: @tax_category,
      store_tax_rate: @non_tax,
      effective_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 5, 31)
    )
    assert_not mapping.valid?
    assert_includes mapping.errors[:ends_on], "must be on or after effective date"
  end

  test "store tax rate must belong to same store" do
    other_store = create_store!(store_number: "002", name: "Store 2")
    other_rate = StoreTaxRate.create!(
      store: other_store, name: "Taxable", short_name: "Taxable", tax_identifier: "T", tax_rate_bps: 950
    )

    mapping = StoreTaxCategoryRate.new(
      store: @store,
      tax_category: @tax_category,
      store_tax_rate: other_rate,
      effective_on: Date.new(2026, 1, 1)
    )
    assert_not mapping.valid?
    assert_includes mapping.errors[:store_tax_rate], "must belong to the same store"
  end

  test "rejects overlapping active mappings" do
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
    assert_not overlapping.valid?
    assert_includes overlapping.errors[:base], "overlaps with another active mapping for this store and tax category"
  end

  test "non-overlapping sequential mappings are allowed" do
    StoreTaxCategoryRate.create!(
      store: @store,
      tax_category: @tax_category,
      store_tax_rate: @non_tax,
      effective_on: Date.new(2026, 1, 1),
      ends_on: Date.new(2026, 6, 30)
    )

    second = StoreTaxCategoryRate.new(
      store: @store,
      tax_category: @tax_category,
      store_tax_rate: @taxable,
      effective_on: Date.new(2026, 7, 1)
    )
    assert second.valid?
  end

  test "inactive mappings do not block overlap validation" do
    StoreTaxCategoryRate.create!(
      store: @store,
      tax_category: @tax_category,
      store_tax_rate: @non_tax,
      effective_on: Date.new(2026, 1, 1),
      ends_on: Date.new(2026, 12, 31),
      active: false
    )

    second = StoreTaxCategoryRate.new(
      store: @store,
      tax_category: @tax_category,
      store_tax_rate: @taxable,
      effective_on: Date.new(2026, 6, 1)
    )
    assert second.valid?
  end
end
