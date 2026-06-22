# frozen_string_literal: true

require "test_helper"

class ItemsCustomerDemandDrawerIntegrationTest < ActionDispatch::IntegrationTest
  include Phase2TestHelper
  include Phase3TestHelper
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(pin: "1234")
    grant_permission!(@user, "items.access", store: @store)
    grant_permission!(@user, "items.catalog_items.view", store: @store)
    grant_permission!(@user, "customer_requests.access", store: @store)
    grant_permission!(@user, "customer_requests.create", store: @store)
    grant_permission!(@user, "inventory_reservations.create", store: @store)
    grant_permission!(@user, "special_orders.create", store: @store)
    login_user!(@user, workstation: @workstation)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 2, line_number: 1 } ]
      ),
      user: @user
    )
    @product = @variant.product
    @customer = create_customer!(display_name: "Drawer Customer")
  end

  test "operations tab shows demand action buttons" do
    get items_item_path(product_id: @product.id, tab: "operations")

    assert_response :success
    assert_includes response.body, "Hold for customer"
    assert_includes response.body, "Notify customer"
  end

  test "create hold from item operations redirects to request show" do
    assert_difference -> { CustomerRequest.count }, 1 do
      post items_customer_demand_path, params: {
        request_type: "hold",
        product_variant_id: @variant.id,
        customer_id: @customer.id,
        quantity: 1,
        expires_at: 14.days.from_now.to_date
      }
    end

    request = CustomerRequest.order(:id).last
    assert_redirected_to customers_customer_request_path(request, anchor: "line-#{request.customer_request_lines.first.id}")
    assert_equal "ready_for_pickup", request.customer_request_lines.first.status
  end

  test "quantity field is outside walk-in fields target" do
    get items_item_path(product_id: @product.id, tab: "operations")

    assert_response :success
    walk_in_block = response.body[/data-customer-lookup-target="walkInFields"[^>]*>[\s\S]*?<\/div>\s*<\/section>/m]
    assert_not_nil walk_in_block
    assert_not_includes walk_in_block, 'name="quantity"'
    assert_match(/<h2>Demand<\/h2>[\s\S]*name="quantity"/, response.body)
  end

  test "create special order from item operations" do
    assert_difference [ -> { CustomerRequest.count }, -> { SpecialOrder.count } ], 1 do
      post items_customer_demand_path, params: {
        request_type: "special_order",
        product_variant_id: @variant.id,
        customer_id: @customer.id,
        quantity: 1
      }
    end

    request = CustomerRequest.order(:id).last
    line = request.customer_request_lines.first
    assert_redirected_to customers_customer_request_path(request, anchor: "line-#{line.id}")
    assert_equal "special_order", line.request_type
    assert_equal "approved", line.special_order.status
  end

  test "create notify without hold permission still works with create only" do
    post items_customer_demand_path, params: {
      request_type: "notify",
      product_variant_id: @variant.id,
      customer_id: @customer.id,
      quantity: 1
    }

    request = CustomerRequest.order(:id).last
    assert_equal "notify", request.customer_request_lines.first.request_type
    assert_redirected_to customers_customer_request_path(request, anchor: "line-#{request.customer_request_lines.first.id}")
  end
end
