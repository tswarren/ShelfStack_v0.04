# frozen_string_literal: true

require "test_helper"

class InventoryRebuildAvailabilityCacheTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase4TestHelper
  include Phase5TestHelper
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 3)
    @demand_line = create_open_demand_line!(store: @store, actor: @user, variant: @variant, quantity: 2)
  end

  test "scoped rebuild sums legacy and v0.04 on hand reservations" do
    DemandAllocations::AllocateOnHand.call!(demand_line: @demand_line, actor: @user, quantity: 2)

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 2, balance.quantity_reserved
    assert_equal 1, balance.quantity_available

    Inventory::RebuildAvailabilityCache.call!(store: @store, product_variant: @variant)
    balance.reload
    assert_equal 2, balance.quantity_reserved
    assert_equal 1, balance.quantity_available
  end
end
