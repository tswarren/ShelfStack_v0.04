# frozen_string_literal: true

require "test_helper"

class CustomersRequestShowIntegrationTest < ActionDispatch::IntegrationTest
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7a_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)
    @request = create_customer_request!(store: @store, created_by_user: @user)
    @line = @request.customer_request_lines.first
    @line.update!(status: "awaiting_customer_response")
  end

  test "show renders line cards and sidebar contact panel" do
    get customers_customer_request_path(@request)

    assert_response :success
    assert_includes response.body, "Request lines"
    assert_includes response.body, "ss-line-card"
    assert_includes response.body, "Next action"
    assert_includes response.body, "Customer contact"
    assert_includes response.body, "Record contact"
  end

  test "show includes hold form stimulus values when line is matched hold" do
    variant = create_product_variant!
    CustomerRequests::MatchVariant.call!(line: @line, variant: variant, actor: @user)
    @line.update!(request_type: "hold", status: "matched")
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: variant, quantity_delta: 2, line_number: 1 } ]
      ),
      user: @user
    )

    get customers_customer_request_path(@request)

    assert_response :success
    assert_includes response.body, 'data-customer-request-hold-form-available-value="2"'
    assert_includes response.body, "customer-request-hold-form-target=\"warning\""
  end
end
