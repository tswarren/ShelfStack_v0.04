# frozen_string_literal: true

require "test_helper"

class CustomerRequestsChangeLineTypeTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!
    @request = create_customer_request!(store: @store, created_by_user: @user)
    @line = @request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
    @line.update!(request_type: "research", status: "matched")
  end

  test "changes line type and refreshes header" do
    CustomerRequests::ChangeLineType.call!(
      request: @request,
      line: @line,
      request_type: "notify",
      actor: @user
    )

    assert_equal "notify", @line.reload.request_type
    assert AuditEvent.exists?(event_name: "customer_request_line.type_changed", auditable: @line)
  end
end
