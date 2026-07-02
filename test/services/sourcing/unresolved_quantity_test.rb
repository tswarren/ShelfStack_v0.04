# frozen_string_literal: true

require "test_helper"

class SourcingUnresolvedQuantityTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase4TestHelper
  include Phase5TestHelper
  include V0047TestHelper
  include V0048TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    grant_v0047_allocation_permissions!(@user)
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @demand = create_special_order_demand!(store: @store, actor: @user, variant: @variant, quantity: 3)
  end

  test "full quantity when nothing allocated or in flight" do
    assert_equal 3, Sourcing::UnresolvedQuantity.for_demand_line(@demand)
  end

  test "subtracts in-flight pending attempt quantity" do
    run = Sourcing::StartRun.call!(demand_line: @demand, actor: @user, quantity: 3)
    vendor = create_vendor_for_variant!(@variant)
    Sourcing::CreateAttempt.call!(sourcing_run: run, actor: @user, vendor: vendor, quantity: 2)

    assert_equal 1, Sourcing::UnresolvedQuantity.for_demand_line(@demand.reload)
  end

  test "subtracts active on-hand allocation" do
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 5)
    DemandAllocations::AllocateOnHand.call!(demand_line: @demand, actor: @user, quantity: 1)

    assert_equal 2, Sourcing::UnresolvedQuantity.for_demand_line(@demand.reload)
  end
end
