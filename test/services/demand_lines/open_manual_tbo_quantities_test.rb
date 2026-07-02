# frozen_string_literal: true

require "test_helper"

class DemandLines::OpenManualTboQuantitiesTest < ActiveSupport::TestCase
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    grant_v0047_allocation_permissions!(@user, store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "sums unallocated manual tbo quantity by variant" do
    DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "manual_tbo",
      quantity: 3,
      variant: @variant
    )

    counts = DemandLines::OpenManualTboQuantities.for_variants(store: @store, variant_ids: [ @variant.id ])

    assert_equal 3, counts.fetch(@variant.id)
  end

  test "excludes fulfilled manual tbo demand" do
    demand_line = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "manual_tbo",
      quantity: 2,
      variant: @variant
    )
    demand_line.update!(status: "fulfilled")

    counts = DemandLines::OpenManualTboQuantities.for_variants(store: @store, variant_ids: [ @variant.id ])

    assert_equal 0, counts.fetch(@variant.id, 0)
  end
end
