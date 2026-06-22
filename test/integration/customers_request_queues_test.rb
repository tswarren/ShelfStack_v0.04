# frozen_string_literal: true

require "test_helper"

class CustomersRequestQueuesTest < ActionDispatch::IntegrationTest
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7a_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)
  end

  test "expiring holds queue lists requests with soon-expiring holds" do
    customer = create_customer!
    request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: customer,
      lines: [ { request_type: "hold" } ]
    )
    line = request.customer_request_lines.first
    variant = create_product_variant!
    CustomerRequests::MatchVariant.call!(line: line, variant: variant, actor: @user)

    InventoryBalance.find_or_create_by!(store: @store, product_variant: variant) do |balance|
      balance.quantity_on_hand = 5
      balance.quantity_reserved = 0
      balance.quantity_available = 5
    end
    InventoryBalance.where(store: @store, product_variant: variant).update_all(quantity_on_hand: 5, quantity_available: 5)

    InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: variant,
      quantity: 1,
      reserved_by_user: @user,
      customer: customer,
      customer_request_line: line,
      expires_at: 1.day.from_now
    )

    get customers_customer_requests_path(queue: "expiring_holds")

    assert_response :success
    assert_includes response.body, request.request_number
  end

  test "needs research queue lists requests with unmatched open lines and shows count badge" do
    matched_request = create_customer_request!(store: @store, created_by_user: @user)
    matched_request.customer_request_lines.first.update!(
      product_variant: create_product_variant!,
      status: "matched"
    )

    unmatched_request = create_customer_request!(store: @store, created_by_user: @user)

    get customers_customer_requests_path(queue: "needs_research")

    assert_response :success
    assert_includes response.body, unmatched_request.request_number
    assert_not_includes response.body, matched_request.request_number
    assert_includes response.body, "Needs research (1)"
  end

  test "request index search finds customer name" do
    customer = create_customer!(display_name: "Queue Search Casey")
    request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: customer
    )

    get customers_customer_requests_path, params: { q: "Queue Search" }

    assert_response :success
    assert_includes response.body, request.request_number
    assert_includes response.body, "Queue Search Casey"
  end
end
