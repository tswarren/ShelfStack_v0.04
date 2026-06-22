# frozen_string_literal: true

require "test_helper"

class PosCompleteReservationFulfillmentTest < ActiveSupport::TestCase
  include Phase2TestHelper
  include Phase6TestHelper
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 3, line_number: 1 } ]
      ),
      user: @user
    )
    @customer = create_customer!
    @customer_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: @customer,
      lines: [ { request_type: "hold", requested_quantity: 3 } ]
    )
    @line = @customer_request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
    @line.update!(status: "ready_for_pickup", requested_quantity: 3)
    @reservation = InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: @variant,
      quantity: 3,
      reserved_by_user: @user,
      customer: @customer,
      customer_request_line: @line
    )
    @reservation.update!(status: "ready")
    @transaction = PosTransaction.create!(
      store: @store,
      workstation: @workstation,
      cashier_user: @user,
      status: "draft"
    )
    @pos_line = Pos::AddReservationLine.call!(
      transaction: @transaction,
      reservation: @reservation,
      added_by_user: @user
    )
  end

  test "partial pickup leaves line and header partially filled" do
    Pos::CompleteReservationFulfillment.call!(transaction: @transaction, fulfilled_by_user: @user)

    assert_equal "partially_filled", @line.reload.status
    assert_equal 1, @line.filled_quantity
    assert_equal "partially_filled", @customer_request.reload.status
    assert_equal "ready", @reservation.reload.status
    assert_equal 1, @reservation.quantity_fulfilled
  end

  test "pickup reduces quantity_ready on linked special order" do
    @line.update!(request_type: "special_order")
    special_order = SpecialOrders::CreateFromRequestLine.call!(line: @line, created_by_user: @user, quantity: 3)
    SpecialOrders::Approve.call!(special_order: special_order, approved_by_user: @user)
    @reservation.update!(special_order: special_order, reservation_type: "special_order_reserve")
    special_order.update!(quantity_ready: 3)

    Pos::CompleteReservationFulfillment.call!(transaction: @transaction, fulfilled_by_user: @user)

    assert_equal 2, special_order.reload.quantity_ready
  end

  test "full pickup completes line and header" do
    @pos_line.update!(quantity: 3)

    Pos::CompleteReservationFulfillment.call!(transaction: @transaction.reload, fulfilled_by_user: @user)

    assert_equal "completed", @line.reload.status
    assert_equal 3, @line.filled_quantity
    assert_equal "completed", @customer_request.reload.status
    assert_equal "fulfilled", @reservation.reload.status
    assert_equal 3, @reservation.quantity_fulfilled
  end
end
