# frozen_string_literal: true

require "test_helper"

class CustomerRequestsNextActionResolverTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!
    @request = create_customer_request!(store: @store, created_by_user: @user)
    @line = @request.customer_request_lines.first
  end

  test "unmatched line suggests match item" do
    action = CustomerRequests::NextActionResolver.for_request(@request, store: @store)

    assert_equal "Match item", action.label
    assert_includes action.path, "line-#{@line.id}"
  end

  test "ready for pickup line suggests ready for pickup" do
    match_request_line!(line: @line, variant: @variant, actor: @user)
    @line.update!(status: "ready_for_pickup")

    action = CustomerRequests::NextActionResolver.for_request(@request.reload, store: @store)

    assert_equal "Ready for pickup", action.label
  end

  test "approved special order suggests attach to po" do
    @request.update!(customer: create_customer!)
    @line.update!(request_type: "special_order")
    match_request_line!(line: @line, variant: @variant, actor: @user)
    special_order = SpecialOrders::CreateFromRequestLine.call!(line: @line, created_by_user: @user)
    SpecialOrders::Approve.call!(special_order: special_order, approved_by_user: @user)

    action = CustomerRequests::NextActionResolver.for_request(@request.reload, store: @store)

    assert_equal "Attach to PO", action.label
  end

  test "for_line resolves action for a single line" do
    action = CustomerRequests::NextActionResolver.for_line(@line, store: @store)

    assert_equal "Match item", action.label
    assert_includes action.path, "line-#{@line.id}"
  end
end
