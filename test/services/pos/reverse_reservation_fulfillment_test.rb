# frozen_string_literal: true

require "test_helper"

class PosReverseReservationFulfillmentTest < ActiveSupport::TestCase
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
      status: "completed"
    )
    @pos_line = @transaction.pos_transaction_lines.create!(
      line_number: 1,
      line_type: "variant",
      product_variant: @variant,
      product: @variant.product,
      quantity: 1,
      unit_price_cents: @variant.selling_price_cents,
      extended_price_cents: @variant.selling_price_cents,
      inventory_reservation_id: @reservation.id,
      customer_request_line_id: @line.id
    )
    InventoryReservations::FulfillAtPos.call!(
      reservation: @reservation,
      pos_transaction_line: @pos_line,
      quantity: 1,
      fulfilled_by_user: @user
    )
    @line.update!(status: "partially_filled", filled_quantity: 1)
    @customer_request.update!(status: "partially_filled")
  end

  test "reverses partial pickup when reservation is still ready" do
    Pos::ReverseReservationFulfillment.call!(transaction: @transaction.reload, reversed_by_user: @user)

    assert_equal "ready", @reservation.reload.status
    assert_equal 0, @reservation.quantity_fulfilled
    assert_equal "ready_for_pickup", @line.reload.status
    assert_equal 0, @line.filled_quantity

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 3, balance.quantity_reserved
    assert_equal 0, balance.quantity_available
    assert AuditEvent.exists?(event_name: "inventory_reservation.fulfillment_reversed", auditable: @reservation)
  end
end
