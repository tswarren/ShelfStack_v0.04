# frozen_string_literal: true

require "test_helper"

class CustomerRequestsMatchVariantTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @user = create_user!
    @customer = create_customer!
    @request = create_customer_request!(store: @store, created_by_user: @user, customer: @customer)
    @line = @request.customer_request_lines.first
    @variant = create_product_variant!
  end

  test "matches line to variant" do
    CustomerRequests::MatchVariant.call!(line: @line, variant: @variant, actor: @user)

    @line.reload
    assert_equal @variant.id, @line.product_variant_id
    assert_equal "matched", @line.status
    assert AuditEvent.exists?(event_name: "customer_request_line.matched_variant", auditable: @line)
  end

  test "rejects already matched line" do
    CustomerRequests::MatchVariant.call!(line: @line, variant: @variant, actor: @user)

    assert_raises(CustomerRequests::MatchVariant::MatchError) do
      CustomerRequests::MatchVariant.call!(line: @line.reload, variant: @variant, actor: @user)
    end
  end
end
