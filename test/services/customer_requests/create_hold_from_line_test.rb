# frozen_string_literal: true

require "test_helper"

class CustomerRequestsCreateHoldFromLineTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 2, line_number: 1 } ]
      ),
      user: @user
    )
    @customer = create_customer!
    @request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: @customer,
      lines: [ { request_type: "hold" } ]
    )
    @line = @request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
  end

  test "creates hold and marks line ready for pickup" do
    reservation = CustomerRequests::CreateHoldFromLine.call!(
      request: @request,
      line: @line,
      store: @store,
      actor: @user,
      quantity: 1
    )

    assert_equal "ready_for_pickup", @line.reload.status
    assert_equal "ready_for_pickup", @request.reload.status
    assert_equal @line.id, reservation.customer_request_line_id
  end
end
