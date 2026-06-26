# frozen_string_literal: true

require "test_helper"

class Items::ReceivingHistoryLookupTest < ActiveSupport::TestCase
  include Phase5TestHelper

  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 4, unit_cost_cents: 900)
  end

  test "for_variants returns posted receipt rows for store" do
    rows = Items::ReceivingHistoryLookup.for_variants(store: @store, variant_ids: [ @variant.id ], limit: 5)

    assert_equal 1, rows.size
    row = rows.first
    assert_equal @variant.id, row.variant_id
    assert_equal 4, row.quantity_accepted
    assert_equal 900, row.unit_cost_cents
    assert_equal @vendor, row.vendor
    assert_equal "posted", row.receipt.status
  end

  test "respects limit" do
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 1, unit_cost_cents: 800)

    rows = Items::ReceivingHistoryLookup.for_variants(store: @store, variant_ids: [ @variant.id ], limit: 1)

    assert_equal 1, rows.size
  end
end
