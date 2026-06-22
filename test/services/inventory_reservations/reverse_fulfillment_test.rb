# frozen_string_literal: true

require "test_helper"

class InventoryReservationsReverseFulfillmentTest < ActiveSupport::TestCase
  include Phase2TestHelper
  include Phase6TestHelper
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
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
    @customer_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: @customer,
      lines: [ { request_type: "special_order", requested_quantity: 2 } ]
    )
    @line = @customer_request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
    @special_order = SpecialOrders::CreateFromRequestLine.call!(line: @line, created_by_user: @user, quantity: 2)
    SpecialOrders::Approve.call!(special_order: @special_order, approved_by_user: @user)
    @reservation = InventoryReservation.create!(
      store: @store,
      customer: @customer,
      customer_request_line: @line,
      special_order: @special_order,
      product_variant: @variant,
      reservation_type: "special_order_reserve",
      status: "fulfilled",
      quantity_reserved: 2,
      quantity_fulfilled: 1,
      reserved_by_user: @user,
      reserved_at: Time.current,
      fulfilled_at: Time.current
    )
    @special_order.update!(quantity_ready: 1, quantity_completed: 1, status: "ready_for_pickup")
  end

  test "void reversal restores quantity_ready on special order" do
    InventoryReservations::ReverseFulfillment.call!(
      reservation: @reservation,
      reversed_by_user: @user,
      quantity: 1
    )

    assert_equal 2, @special_order.reload.quantity_ready
    assert_equal 0, @special_order.quantity_completed
  end
end
