# frozen_string_literal: true

require "test_helper"

class PosCustomerPickupLookupTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 1, line_number: 1 } ]
      ),
      user: @user
    )
    @customer_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      lines: [ { request_type: "hold", requested_quantity: 1 } ]
    )
    @line = @customer_request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
    @reservation = InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: @variant,
      quantity: 1,
      reserved_by_user: @user,
      customer: nil,
      customer_request_line: @line
    )
    @reservation.update!(status: "ready")
    @line.update!(status: "ready_for_pickup")
  end

  test "finds walk-in snapshot customer by name" do
    rows = Pos::CustomerPickupLookup.ready_for_store(store: @store, query: @customer_request.customer_name_snapshot)

    assert_equal 1, rows.size
    assert_equal @customer_request.customer_name_snapshot, rows.first.customer_name
    assert_equal @reservation.id, rows.first.reservation_id
  end
end
