# frozen_string_literal: true

require "test_helper"

class ItemsCustomerDemandDrawerIntegrationTest < ActionDispatch::IntegrationTest
  include Phase2TestHelper
  include Phase3TestHelper
  include Phase7aTestHelper

  setup do
    Seeds::V0046Permissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(pin: "1234")
    grant_permission!(@user, "items.access", store: @store)
    grant_permission!(@user, "items.catalog_items.view", store: @store)
    grant_permission!(@user, "demand.access", store: @store)
    grant_permission!(@user, "demand.create", store: @store)
    login_user!(@user, workstation: @workstation)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @product = @variant.product
    @customer = create_customer!(display_name: "Drawer Customer")
  end

  test "operations tab includes unified variant operations drawer shell" do
    get items_item_path(product_id: @product.id, tab: "operations")

    assert_response :success
    assert_includes response.body, 'id="item-variant-ops-drawer"'
    assert_includes response.body, "ss-drawer"
    assert_includes response.body, 'id="demand_form_reset_triggers"'
  end

  test "variant operations drawer body includes v0.04 demand actions" do
    get items_variant_operations_drawer_path(product_variant_id: @variant.id)

    assert_response :success
    assert_includes response.body, "Record hold request"
    assert_includes response.body, "Notify customer"
    assert_includes response.body, "Manual TBO / replenishment"
  end

  test "create hold from item operations creates demand line" do
    assert_difference -> { DemandLine.count }, 1 do
      post items_demand_path, params: {
        capture_intent: "hold",
        product_variant_id: @variant.id,
        customer_id: @customer.id,
        quantity: 1,
        expires_at: 14.days.from_now.to_date
      }
    end

    demand_line = DemandLine.order(:id).last
    assert_redirected_to demand_demand_line_path(demand_line)
    assert_equal "hold", demand_line.capture_intent
    assert_equal "open", demand_line.status
  end

  test "create special order from item operations creates demand line only" do
    assert_difference -> { DemandLine.count }, 1 do
      post items_demand_path, params: {
        capture_intent: "special_order",
        product_variant_id: @variant.id,
        customer_id: @customer.id,
        quantity: 1
      }
    end

    demand_line = DemandLine.order(:id).last
    assert_equal "special_order", demand_line.capture_intent
  end

  test "create hold via turbo stream refreshes drawer" do
    post items_demand_path,
         params: {
           capture_intent: "hold",
           product_variant_id: @variant.id,
           customer_id: @customer.id,
           quantity: 1,
           expires_at: 14.days.from_now.to_date
         },
         as: :turbo_stream

    assert_response :success
    assert_includes response.body, 'target="variant-ops-drawer-frame"'
    assert_includes response.body, 'target="toast_region"'
  end

  test "special order validation error appends error toast via turbo stream" do
    post items_demand_path,
         params: {
           capture_intent: "special_order",
           product_variant_id: @variant.id,
           quantity: 1,
           customer_name_snapshot: "Walk-in Guest"
         },
         as: :turbo_stream

    assert_response :unprocessable_entity
    assert_includes response.body, "ss-toast--error"
    assert_includes response.body, "Customer record is required"
  end
end
