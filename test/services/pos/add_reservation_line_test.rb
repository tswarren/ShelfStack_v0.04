# frozen_string_literal: true

require "test_helper"

class PosAddReservationLineTest < ActiveSupport::TestCase
  include Phase2TestHelper
  include Phase6TestHelper
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7a_permissions!(@user, store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
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
      lines: [ { request_type: "hold" } ]
    )
    @line = @customer_request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
    @reservation = InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: @variant,
      quantity: 1,
      reserved_by_user: @user,
      customer: @customer,
      customer_request_line: @line,
      expires_at: 7.days.from_now
    )
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    @transaction = PosTransaction.create!(
      store: @store,
      workstation: @workstation,
      cashier_user: @user,
      status: "draft"
    )
  end

  test "creates pickup line linked to reservation and customer" do
    line = Pos::AddReservationLine.call!(
      transaction: @transaction,
      reservation: @reservation,
      added_by_user: @user
    )

    assert_equal @reservation.id, line.inventory_reservation_id
    assert_equal @customer.id, @transaction.reload.customer_id
    assert_equal 1, line.quantity
  end

  test "rejects mismatched demand chain" do
    other_customer = create_customer!(display_name: "Other Customer")
    @reservation.update!(customer: other_customer)

    assert_raises(Pos::AddReservationLine::Error) do
      Pos::AddReservationLine.call!(
        transaction: @transaction,
        reservation: @reservation,
        added_by_user: @user
      )
    end
  end
end
