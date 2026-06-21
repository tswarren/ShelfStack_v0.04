# frozen_string_literal: true

require "test_helper"

class CustomerRequestsCreateTest < ActiveSupport::TestCase
  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
  end

  test "creates request with numbered lines and audit event" do
    customer = create_customer!

    request = CustomerRequests::Create.call(
      store: @store,
      created_by_user: @user,
      attributes: { customer: customer, source: "in_store" },
      lines: [ { request_type: "research", requested_quantity: 2, provisional_title: "Obscure Book" } ]
    )

    assert request.request_number.start_with?("REQ-#{@store.store_number}-")
    assert_equal 1, request.customer_request_lines.count
    assert_equal 2, request.customer_request_lines.first.requested_quantity
    assert AuditEvent.exists?(event_name: "customer_request.created", auditable: request)
  end
end
