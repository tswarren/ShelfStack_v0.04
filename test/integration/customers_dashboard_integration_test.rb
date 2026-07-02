# frozen_string_literal: true

require "test_helper"

class CustomersDashboardIntegrationTest < ActionDispatch::IntegrationTest
  include Phase7aTestHelper
  include V0047TestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    seed_v0047_permissions!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7a_permissions!(@user, store: @store)
    grant_v0047_allocation_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)

    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 2, line_number: 1 } ]
      ),
      user: @user
    )
    @ready_demand = create_hold_with_on_hand_allocation!(store: @store, actor: @user, variant: @variant, quantity: 1)
  end

  test "customers root renders dashboard instead of redirecting" do
    get customers_root_path

    assert_response :success
    assert_includes response.body, "Customer Demand"
    assert_includes response.body, "Ready for pickup"
    assert_includes response.body, @ready_demand.demand_number
  end

  test "dashboard queue card links to filtered demand index" do
    get customers_root_path

    assert_includes response.body, demand_demand_lines_path(queue: "ready_for_pickup")
  end
end
