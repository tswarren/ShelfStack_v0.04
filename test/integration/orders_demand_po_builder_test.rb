# frozen_string_literal: true

require "test_helper"

class OrdersDemandPoBuilderTest < ActionDispatch::IntegrationTest
  include Phase7aTestHelper
  include Phase5TestHelper

  setup do
    seed_phase3_reference_data!
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "pobuilder", password: "Password123!")
    grant_permission!(@user, "orders.access", store: @store)
    grant_permission!(@user, "orders.purchase_orders.view", store: @store)
    grant_permission!(@user, "orders.purchase_orders.create", store: @store)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "pobuilder", password: "Password123!" }
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    ProductVendor.create!(product: @variant.product, vendor: @vendor, active: true, preferred: true)
    @demand = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: create_customer!,
      quantity: 1
    )
  end

  test "create draft PO from demand builder" do
    post orders_demand_po_builder_path, params: {
      demand_line_ids: [ @demand.id ],
      vendor_groups: {
        @vendor.id.to_s => { mode: "create_new" }
      }
    }

    purchase_order = PurchaseOrder.order(:id).last
    assert_redirected_to orders_purchase_order_path(purchase_order)
    assert purchase_order.purchase_order_line_demand_plans.active_plans.exists?
  end
end
