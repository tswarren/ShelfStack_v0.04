# frozen_string_literal: true

require "test_helper"

class OrdersBuyerWorkbenchTest < ActionDispatch::IntegrationTest
  include Phase7aTestHelper
  include Phase5TestHelper

  setup do
    seed_phase3_reference_data!
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "buyerwb", password: "Password123!")
    grant_permission!(@user, "orders.access", store: @store)
    grant_permission!(@user, "orders.purchase_orders.view", store: @store)
    grant_permission!(@user, "orders.purchase_orders.create", store: @store)
    grant_permission!(@user, "demand.access", store: @store)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "buyerwb", password: "Password123!" }
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    ProductVendor.create!(product: @variant.product, vendor: @vendor, active: true, preferred: true)
  end

  test "buyer workbench lists demand and bulk redirects to PO builder" do
    demand = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: create_customer!,
      quantity: 1
    )

    get orders_buyer_workbench_path(tab: "needs_ordering")
    assert_response :success
    assert_match demand.demand_number, response.body

    get new_orders_demand_po_builder_path, params: { demand_line_ids: [ demand.id ] }
    assert_response :success
    assert_match @vendor.name, response.body
  end
end
