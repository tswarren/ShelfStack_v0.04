# frozen_string_literal: true

require "test_helper"

class Pos::WorkspaceLinesControllerTest < ActionDispatch::IntegrationTest
  include Phase2TestHelper
  include Phase6TestHelper
  include Phase7aTestHelper
  include V0047TestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    seed_v0047_permissions!
    @cashier = create_user!(username: "workspace_lines_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, login: true, inventory_qty: 2, inventory_behavior: "standard_physical")
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @register_session = @ctx[:register_session]
    @variant = @ctx[:variant]
    grant_all_phase7a_permissions!(@cashier, store: @store)
    grant_v0047_allocation_permissions!(@cashier, store: @store)
    grant_permission!(@cashier, "pos.fulfill_customer_reservation", store: @store)

    @customer = create_customer!(display_name: "Workspace Pickup Pat")
    @demand_line = DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @cashier,
      capture_intent: "hold",
      quantity: 1,
      customer: @customer
    ).demand_line
    @allocation = @demand_line.demand_allocations.active_allocations.on_hand_kind.first
  end

  test "workspace add demand allocation line creates draft and redirects to edit" do
    assert_difference -> { PosTransaction.count }, 1 do
      post pos_workspace_add_demand_allocation_line_path,
           params: { demand_allocation_id: @allocation.id, quantity: 1 }
    end

    transaction = PosTransaction.drafts.order(:id).last
    assert_redirected_to edit_pos_transaction_path(transaction, mode: "sale")
    assert_equal 1, transaction.pos_transaction_lines.count
    assert_equal @allocation.id, transaction.pos_transaction_lines.first.demand_allocation_id
  end

  test "workspace add no receipt line creates draft with negative quantity" do
    assert_difference -> { PosTransaction.count }, 1 do
      post pos_workspace_add_no_receipt_line_path,
           params: { product_variant_id: @variant.id, quantity: -1 }
    end

    transaction = PosTransaction.drafts.order(:id).last
    assert_redirected_to edit_pos_transaction_path(transaction, mode: "sale")
    line = transaction.pos_transaction_lines.sole
    assert_equal(-1, line.quantity)
    assert_equal "return_to_stock", line.return_disposition
  end

  test "workspace add open ring line creates draft and redirects to edit" do
    sub_department = @variant.sub_department

    assert_difference -> { PosTransaction.count }, 1 do
      post pos_workspace_add_open_ring_line_path,
           params: {
             description: "Gift wrap",
             sub_department_id: sub_department.id,
             unit_price: "5.00",
             quantity: 1
           }
    end

    transaction = PosTransaction.drafts.order(:id).last
    assert_redirected_to edit_pos_transaction_path(transaction, mode: "sale")
    line = transaction.pos_transaction_lines.sole
    assert line.open_ring_line?
    assert_equal "Gift wrap", line.open_ring_description
    assert_equal 500, line.unit_price_cents
  end

  test "workspace add open ring return creates negative open ring line" do
    sub_department = @variant.sub_department

    assert_difference -> { PosTransaction.count }, 1 do
      post pos_workspace_add_open_ring_line_path,
           params: {
             entry_action: "return_no_receipt",
             description: "Misc return",
             sub_department_id: sub_department.id,
             unit_price: "8.00",
             quantity: -1
           }
    end

    transaction = PosTransaction.drafts.order(:id).last
    assert_redirected_to edit_pos_transaction_path(transaction, mode: "sale")
    line = transaction.pos_transaction_lines.sole
    assert line.open_ring_line?
    assert_equal(-1, line.quantity)
    assert_equal "return_to_stock", line.return_disposition
  end
end
