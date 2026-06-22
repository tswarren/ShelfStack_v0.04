# frozen_string_literal: true

require "test_helper"

class CustomerRequestsMarkAwaitingResponseTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!
    @request = create_customer_request!(store: @store, created_by_user: @user)
    @line = @request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
    @line.update!(request_type: "notify", status: "matched")
  end

  test "marks line awaiting response" do
    CustomerRequests::MarkAwaitingResponse.call!(
      request: @request,
      line: @line,
      actor: @user
    )

    assert_equal "awaiting_customer_response", @line.reload.status
    assert_equal "awaiting_customer_response", @request.reload.status
  end
end
