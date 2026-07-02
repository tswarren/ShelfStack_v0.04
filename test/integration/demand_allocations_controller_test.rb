# frozen_string_literal: true

require "test_helper"

class DemandAllocationsControllerTest < ActionDispatch::IntegrationTest
  include Phase2TestHelper
  include Phase3TestHelper
  include Phase4TestHelper
  include Phase5TestHelper
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(pin: "1234")
    grant_v0047_allocation_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 5)
    @demand_line = create_open_demand_line!(store: @store, actor: @user, variant: @variant, quantity: 2)
  end

  test "create on hand allocation from demand show" do
    post demand_demand_line_allocations_path(@demand_line), params: { quantity: 1 }

    assert_redirected_to demand_demand_line_path(@demand_line)
    assert_equal 1, @demand_line.demand_allocations.active_allocations.count
  end

  test "index filters unallocated notify lines" do
    notify_line = create_open_demand_line!(
      store: @store,
      actor: @user,
      variant: @variant,
      capture_intent: "notify"
    )
    DemandAllocations::AllocateOnHand.call!(demand_line: @demand_line, actor: @user, quantity: 1)

    get demand_root_path, params: { allocation_state: "unallocated", capture_intent: "notify" }

    assert_response :success
    assert_includes response.body, notify_line.demand_number
    assert_not_includes response.body, @demand_line.demand_number
  end
end
