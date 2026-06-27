# frozen_string_literal: true

require "test_helper"

class Pos::WorkspaceLinesControllerTest < ActionDispatch::IntegrationTest
  include Phase2TestHelper
  include Phase6TestHelper
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @cashier = create_user!(username: "workspace_lines_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, login: true, inventory_qty: 2, inventory_behavior: "standard_physical")
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @register_session = @ctx[:register_session]
    @variant = @ctx[:variant]
    grant_all_phase7a_permissions!(@cashier, store: @store)

    @customer = create_customer!(display_name: "Workspace Pickup Pat")
    @customer_request = create_customer_request!(
      store: @store,
      created_by_user: @cashier,
      customer: @customer,
      lines: [ { request_type: "hold" } ]
    )
    @line = @customer_request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @cashier)
    @reservation = InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: @variant,
      quantity: 1,
      reserved_by_user: @cashier,
      customer: @customer,
      customer_request_line: @line
    )
    @reservation.update!(status: "ready")
  end

  test "workspace add reservation line creates draft and redirects to edit" do
    assert_difference -> { PosTransaction.count }, 1 do
      post pos_workspace_add_reservation_line_path,
           params: { inventory_reservation_id: @reservation.id, quantity: 1 }
    end

    transaction = PosTransaction.drafts.order(:id).last
    assert_redirected_to edit_pos_transaction_path(transaction, mode: "sale")
    assert_equal 1, transaction.pos_transaction_lines.count
  end
end
