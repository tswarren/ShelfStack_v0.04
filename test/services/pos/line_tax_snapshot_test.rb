# frozen_string_literal: true

require "test_helper"

class Pos::LineTaxSnapshotTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @variant = create_product_variant!(selling_price_cents: 1000)
    @tax_category = @variant.sub_department.default_tax_category
    @rate = create_store_tax_rate!(store: @store, tax_rate_bps: 600)
    create_store_tax_category_rate!(store: @store, tax_category: @tax_category, store_tax_rate: @rate)
    @line = PosTransactionLine.new(
      line_number: 1,
      line_type: "variant",
      quantity: 1,
      unit_price_cents: 1000,
      extended_price_cents: 1000
    )
  end

  test "persists tax identifier and short name snapshots from store tax rate" do
    Pos::LineTaxSnapshot.apply!(
      @line,
      tax_category: @tax_category,
      store_tax_rate: @rate,
      tax_rate_bps: 600,
      tax_cents: 60
    )

    assert_equal @rate.tax_identifier, @line.tax_identifier_snapshot
    assert_equal @rate.short_name, @line.store_tax_rate_short_name_snapshot
    assert_equal 60, @line.tax_cents
  end
end
