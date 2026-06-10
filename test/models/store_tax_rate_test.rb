# frozen_string_literal: true

require "test_helper"

class StoreTaxRateTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
  end

  test "valid store tax rate" do
    rate = StoreTaxRate.new(
      store: @store,
      name: "Taxable",
      short_name: "Taxable",
      tax_identifier: "T",
      tax_rate_bps: 600
    )
    assert rate.valid?
    assert rate.save
  end

  test "tax_rate_bps must be between 0 and 10000" do
    rate = StoreTaxRate.new(
      store: @store,
      name: "Bad",
      short_name: "Bad",
      tax_identifier: "B",
      tax_rate_bps: 10_001
    )
    assert_not rate.valid?

    rate.tax_rate_bps = -1
    assert_not rate.valid?
  end

  test "name short_name and tax_identifier unique per store" do
    StoreTaxRate.create!(
      store: @store, name: "Taxable", short_name: "Taxable", tax_identifier: "T", tax_rate_bps: 600
    )

    duplicate = StoreTaxRate.new(
      store: @store, name: "Taxable", short_name: "Other", tax_identifier: "O", tax_rate_bps: 0
    )
    assert_not duplicate.valid?

    other_store = create_store!(store_number: "002", name: "Store 2")
    other = StoreTaxRate.new(
      store: other_store, name: "Taxable", short_name: "Taxable", tax_identifier: "T", tax_rate_bps: 600
    )
    assert other.valid?
  end

  test "normalizes tax identifier to uppercase" do
    rate = StoreTaxRate.create!(
      store: @store, name: "Non-Taxable", short_name: "Non-Tax", tax_identifier: "n", tax_rate_bps: 0
    )
    assert_equal "N", rate.tax_identifier
  end
end
