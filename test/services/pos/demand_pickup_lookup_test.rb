# frozen_string_literal: true

require "test_helper"

class PosDemandPickupLookupTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase4TestHelper
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    grant_v0047_allocation_permissions!(@user, store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 5)
    @customer = create_customer!(display_name: "Pickup Pat")
    @demand_line = DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      capture_intent: "hold",
      quantity: 1,
      customer: @customer
    ).demand_line
    @allocation = @demand_line.demand_allocations.active_allocations.on_hand_kind.first
  end

  test "returns active on-hand allocations ready for pickup" do
    rows = Pos::DemandPickupLookup.ready_for_store(store: @store)

    assert_equal 1, rows.size
    assert_equal @allocation.id, rows.first.demand_allocation_id
    assert_equal @demand_line.demand_number, rows.first.demand_number
  end

  test "filters by demand number" do
    rows = Pos::DemandPickupLookup.ready_for_store(store: @store, demand_number: @demand_line.demand_number)

    assert_equal 1, rows.size
  end

  test "excludes expired allocations" do
    @allocation.update!(expires_at: 1.hour.ago)

    rows = Pos::DemandPickupLookup.ready_for_store(store: @store)

    assert_empty rows
  end
end
