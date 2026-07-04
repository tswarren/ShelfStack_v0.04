# frozen_string_literal: true

require "test_helper"

class DemandLineShowCapstoneTest < ActionDispatch::IntegrationTest
  include Phase7aTestHelper

  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "demandshow", password: "Password123!")
    grant_permission!(@user, "demand.access", store: @store)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "demandshow", password: "Password123!" }
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @demand = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: create_customer!,
      quantity: 1
    )
  end

  test "demand show renders supply strip and next action panel" do
    get demand_demand_line_path(@demand)
    assert_response :success
    assert_match "Supply status", response.body
    assert_match "Available supply", response.body
    assert_match "demand-next-action-panel", response.body
  end
end
