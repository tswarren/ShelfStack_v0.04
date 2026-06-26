# frozen_string_literal: true

require "test_helper"

class Items::VariantOperationalSnapshotTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase5_reference_data!
    @store = create_store!
    @vendor = create_vendor!(default_supplier_discount_bps: 4000)
    @variant = create_product_variant!(inventory_behavior: "standard_physical", selling_price_cents: 1500)
    @variant.product.update!(list_price_cents: 0)
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      supplier_discount_bps: 4000,
      active: true,
      preferred: true
    )
  end

  test "expected unit cost falls back to variant selling price when product list price is zero" do
    snapshot = Items::VariantOperationalSnapshot.for_variants(store: @store, variants: [ @variant ])
    row = snapshot.rows.fetch(@variant.id)

    assert_equal 900, row.expected_unit_cost_cents
  end

  test "expected unit cost is nil when list and selling price are zero" do
    @variant.product.update!(list_price_cents: 0, preferred_vendor: @vendor)
    @variant.update!(selling_price_cents: 0)

    snapshot = Items::VariantOperationalSnapshot.for_variants(store: @store, variants: [ @variant ])
    row = snapshot.rows.fetch(@variant.id)

    assert_nil row.expected_unit_cost_cents
  end
end
