# frozen_string_literal: true

require "test_helper"

class CustomersRequestMatchIntegrationTest < ActionDispatch::IntegrationTest
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7a_permissions!(@user, store: @store)
    grant_permission!(@user, "items.access", store: @store)
    grant_permission!(@user, "items.catalog_items.view", store: @store)
    grant_permission!(@user, "items.external_lookup.access", store: @store)
    grant_permission!(@user, "items.catalog_items.create", store: @store)
    login_user!(@user, workstation: @workstation)

    @customer = create_customer!
    @customer_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: @customer,
      lines: [ { provisional_identifier: "9780123456789", provisional_title: "Match Me" } ]
    )
    @line = @customer_request.customer_request_lines.first
    @variant = create_product_variant!(sku: "MATCHSKU001")
  end

  test "match_variant links line from request show flow" do
    post match_variant_customers_customer_request_path(@customer_request),
         params: { line_id: @line.id, product_variant_id: @variant.id }

    assert_redirected_to customers_customer_request_path(@customer_request, anchor: "line-#{@line.id}")
    assert_equal @variant.id, @line.reload.product_variant_id
  end

  test "items search preserves match context" do
    get items_root_path(
      return_to: Customers::RequestMatchContext::RETURN_TO,
      customer_request_id: @customer_request.id,
      line_id: @line.id,
      q: "MATCHSKU"
    )

    assert_response :success
    assert_includes response.body, @customer_request.request_number
  end

  test "items index match button posts to match_variant" do
    get items_root_path(
      return_to: Customers::RequestMatchContext::RETURN_TO,
      customer_request_id: @customer_request.id,
      line_id: @line.id,
      q: @variant.sku
    )
    assert_response :success

    post match_variant_customers_customer_request_path(@customer_request),
         params: { line_id: @line.id, product_variant_id: @variant.id }

    assert_equal @variant.id, @line.reload.product_variant_id
  end

  test "add item identify shows match banner when draft has match context" do
    get items_add_item_path(
      step: "choose_path",
      return_to: Customers::RequestMatchContext::RETURN_TO,
      customer_request_id: @customer_request.id,
      line_id: @line.id
    )
    assert_response :success

    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }
    follow_redirect!

    get items_add_item_path(step: "identify")
    assert_response :success
    assert_includes response.body, @customer_request.request_number
  end
end
