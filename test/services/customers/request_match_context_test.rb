# frozen_string_literal: true

require "test_helper"

class CustomersRequestMatchContextTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @user = create_user!
    @customer = create_customer!
    @request = create_customer_request!(store: @store, created_by_user: @user, customer: @customer)
    @line = @request.customer_request_lines.first
  end

  test "valid when params match store and open line" do
    context = Customers::RequestMatchContext.new(
      return_to: Customers::RequestMatchContext::RETURN_TO,
      customer_request_id: @request.id,
      line_id: @line.id,
      store: @store
    )

    assert context.valid?
    assert_equal @request.id, context.request_record.id
    assert_equal @line.id, context.line.id
  end

  test "invalid for wrong store" do
    other_store = create_store!(store_number: "999", name: "Other Store")
    context = Customers::RequestMatchContext.new(
      return_to: Customers::RequestMatchContext::RETURN_TO,
      customer_request_id: @request.id,
      line_id: @line.id,
      store: other_store
    )

    assert_not context.valid?
  end

  test "invalid for terminal line" do
    @line.update!(status: "cancelled")
    context = Customers::RequestMatchContext.from_params(
      {
        return_to: Customers::RequestMatchContext::RETURN_TO,
        customer_request_id: @request.id,
        line_id: @line.id
      },
      store: @store
    )

    assert_not context.valid?
  end
end
