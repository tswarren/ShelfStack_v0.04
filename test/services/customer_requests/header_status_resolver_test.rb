# frozen_string_literal: true

require "test_helper"

class CustomerRequestsHeaderStatusResolverTest < ActiveSupport::TestCase
  setup do
    Seeds::Phase7aPermissions.seed!
    seed_phase3_reference_data!
    @store = create_store!
    @user = create_user!
    @customer = create_customer!
    @variant = create_product_variant!
  end

  test "derives ready_for_pickup when all active lines ready" do
    request = create_customer_request!(store: @store, created_by_user: @user, customer: @customer)
    line = request.customer_request_lines.first
    line.update!(product_variant: @variant, status: "matched", request_type: "hold")
    line.update!(status: "ready_for_pickup")

    CustomerRequests::HeaderStatusResolver.call!(request)

    assert_equal "ready_for_pickup", request.reload.status
  end

  test "derives researching when lines are matched" do
    request = create_customer_request!(store: @store, created_by_user: @user, customer: @customer)
    request.customer_request_lines.first.update!(status: "matched", product_variant: @variant)

    CustomerRequests::HeaderStatusResolver.call!(request)

    assert_equal "researching", request.reload.status
  end

  test "derives completed when all active lines are completed" do
    request = create_customer_request!(store: @store, created_by_user: @user, customer: @customer)
    line = request.customer_request_lines.first
    line.update!(
      product_variant: @variant,
      request_type: "hold",
      status: "completed",
      requested_quantity: 1,
      filled_quantity: 1
    )

    CustomerRequests::HeaderStatusResolver.call!(request)

    assert_equal "completed", request.reload.status
  end

  test "derives partially_filled when one line completed and another still open" do
    request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: @customer,
      lines: [ { request_type: "hold" }, { request_type: "hold" } ]
    )
    completed_line, open_line = request.customer_request_lines.order(:line_number)
    completed_line.update!(
      product_variant: @variant,
      status: "completed",
      requested_quantity: 1,
      filled_quantity: 1
    )
    open_line.update!(product_variant: @variant, status: "ready_for_pickup")

    CustomerRequests::HeaderStatusResolver.call!(request)

    assert_equal "partially_filled", request.reload.status
  end

  test "derives partially_filled when a line is partially filled" do
    request = create_customer_request!(store: @store, created_by_user: @user, customer: @customer)
    request.customer_request_lines.first.update!(
      product_variant: @variant,
      request_type: "hold",
      status: "partially_filled",
      requested_quantity: 3,
      filled_quantity: 1
    )

    CustomerRequests::HeaderStatusResolver.call!(request)

    assert_equal "partially_filled", request.reload.status
  end

  test "records status_changed audit event when header status changes" do
    request = create_customer_request!(store: @store, created_by_user: @user, customer: @customer)
    line = request.customer_request_lines.first
    line.update!(product_variant: @variant, status: "matched", request_type: "hold")
    line.update!(status: "ready_for_pickup")

    assert_difference -> { AuditEvent.where(event_name: "customer_request.status_changed", auditable: request).count }, 1 do
      CustomerRequests::HeaderStatusResolver.call!(request, actor: @user, source: line)
    end

    event = AuditEvent.where(event_name: "customer_request.status_changed", auditable: request).last
    assert_equal "new", event.event_details["prior_status"]
    assert_equal "ready_for_pickup", event.event_details["new_status"]
  end

  test "does not record audit event when header status unchanged" do
    request = create_customer_request!(store: @store, created_by_user: @user, customer: @customer)
    request.update!(status: "researching")
    request.customer_request_lines.first.update!(status: "matched", product_variant: @variant)

    assert_no_difference -> { AuditEvent.where(event_name: "customer_request.status_changed", auditable: request).count } do
      CustomerRequests::HeaderStatusResolver.call!(request, actor: @user)
    end
  end
end
