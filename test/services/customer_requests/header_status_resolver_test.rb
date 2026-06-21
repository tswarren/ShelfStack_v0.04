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
end
