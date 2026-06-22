# frozen_string_literal: true

require "test_helper"

class CustomerRequestsUnfillableEligibilityTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @customer = create_customer!
  end

  test "allows unfillable for early research line" do
    request = create_customer_request!(store: @store, created_by_user: @user)
    result = CustomerRequests::UnfillableEligibility.check(request)

    assert result.allowed
    assert_empty result.reasons
  end

  test "blocks unfillable when line has on-hand hold" do
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 1, line_number: 1 } ]
      ),
      user: @user
    )
    request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: @customer,
      lines: [ { request_type: "hold" } ]
    )
    line = request.customer_request_lines.first
    match_request_line!(line: line, variant: @variant, actor: @user)
    CustomerRequests::CreateHoldFromLine.call!(
      request: request,
      line: line,
      store: @store,
      actor: @user,
      quantity: 1
    )

    result = CustomerRequests::UnfillableEligibility.check(request.reload)

    assert_not result.allowed
    assert result.reasons.any? { |reason| reason.include?("active reservation") || reason.include?("ready for pickup") }
  end

  test "mark unfillable raises when request is held" do
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 1, line_number: 1 } ]
      ),
      user: @user
    )
    request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: @customer,
      lines: [ { request_type: "hold" } ]
    )
    line = request.customer_request_lines.first
    match_request_line!(line: line, variant: @variant, actor: @user)
    CustomerRequests::CreateHoldFromLine.call!(
      request: request,
      line: line,
      store: @store,
      actor: @user,
      quantity: 1
    )

    error = assert_raises(CustomerRequests::MarkUnfillable::MarkUnfillableError) do
      CustomerRequests::MarkUnfillable.call!(request: request.reload, actor: @user, reason: "Cannot source")
    end

    assert_match(/reservation|ready for pickup/i, error.message)
    assert_equal "ready_for_pickup", request.reload.status
  end
end
