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

  test "show includes release for on-hand hold reservation" do
    variant = create_product_variant!(inventory_behavior: "standard_physical")
    customer = create_customer!
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: variant, quantity_delta: 1, line_number: 1 } ]
      ),
      user: @user
    )
    request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: customer,
      lines: [ { request_type: "hold" } ]
    )
    line = request.customer_request_lines.first
    match_request_line!(line: line, variant: variant, actor: @user)
    CustomerRequests::CreateHoldFromLine.call!(
      request: request,
      line: line,
      store: @store,
      actor: @user,
      quantity: 1
    )

    get customers_customer_request_path(request)

    assert_response :success
    assert_includes response.body, "Release"
    assert_includes response.body, release_hold_customers_customer_request_path(request)
  end

  test "show does not include release for special order reserve" do
    variant = create_product_variant!(inventory_behavior: "standard_physical")
    customer = create_customer!
    request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: customer,
      lines: [ { request_type: "special_order" } ]
    )
    line = request.customer_request_lines.first
    match_request_line!(line: line, variant: variant, actor: @user)
    special_order = SpecialOrders::CreateFromRequestLine.call!(line: line, created_by_user: @user)
    SpecialOrders::Approve.call!(special_order: special_order, approved_by_user: @user)
    InventoryReservation.create!(
      store: @store,
      customer: customer,
      customer_request_line: line,
      special_order: special_order,
      product_variant: variant,
      reservation_type: "special_order_reserve",
      status: "ready",
      quantity_reserved: 1,
      reserved_by_user: @user,
      reserved_at: Time.current,
      ready_at: Time.current
    )
    line.update!(status: "ready_for_pickup")

    get customers_customer_request_path(request)

    assert_response :success
    assert_includes response.body, "Ready for pickup via special order"
    refute_includes response.body, release_hold_customers_customer_request_path(request)
  end

  test "post release_hold rejects special order reserve" do
    variant = create_product_variant!(inventory_behavior: "standard_physical")
    customer = create_customer!
    request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: customer,
      lines: [ { request_type: "special_order" } ]
    )
    line = request.customer_request_lines.first
    match_request_line!(line: line, variant: variant, actor: @user)
    special_order = SpecialOrders::CreateFromRequestLine.call!(line: line, created_by_user: @user)
    reservation = InventoryReservation.create!(
      store: @store,
      customer: customer,
      customer_request_line: line,
      special_order: special_order,
      product_variant: variant,
      reservation_type: "special_order_reserve",
      status: "ready",
      quantity_reserved: 1,
      reserved_by_user: @user,
      reserved_at: Time.current,
      ready_at: Time.current
    )

    post release_hold_customers_customer_request_path(request),
         params: { reservation_id: reservation.id, release_reason: "staff_release" }

    assert_redirected_to customers_customer_request_path(request)
    assert_match(/on-hand hold/i, flash[:alert])
    assert_equal "ready", reservation.reload.status
  end

  test "held request hides mark unfillable panel" do
    variant = create_product_variant!(inventory_behavior: "standard_physical")
    customer = create_customer!
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: variant, quantity_delta: 1, line_number: 1 } ]
      ),
      user: @user
    )
    request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: customer,
      lines: [ { request_type: "hold" } ]
    )
    line = request.customer_request_lines.first
    match_request_line!(line: line, variant: variant, actor: @user)
    CustomerRequests::CreateHoldFromLine.call!(
      request: request,
      line: line,
      store: @store,
      actor: @user,
      quantity: 1
    )

    get customers_customer_request_path(request)

    assert_response :success
    refute_includes response.body, 'value="Mark unfillable"'
    assert_includes response.body, "Mark unfillable is not available"
  end

  test "research request shows mark unfillable panel" do
    get customers_customer_request_path(@request)

    assert_response :success
    assert_includes response.body, 'value="Mark unfillable"'
  end

  test "hold creation records status_changed in audit timeline" do
    variant = create_product_variant!(inventory_behavior: "standard_physical")
    customer = create_customer!
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: variant, quantity_delta: 1, line_number: 1 } ]
      ),
      user: @user
    )
    request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: customer,
      lines: [ { request_type: "hold" } ]
    )
    line = request.customer_request_lines.first
    match_request_line!(line: line, variant: variant, actor: @user)
    CustomerRequests::CreateHoldFromLine.call!(
      request: request,
      line: line,
      store: @store,
      actor: @user,
      quantity: 1
    )

    get customers_customer_request_path(request)

    assert_response :success
    assert_includes response.body, "customer_request.status_changed"
  end
end
