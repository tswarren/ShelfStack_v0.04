# frozen_string_literal: true

require "test_helper"

class PosCompletedWorkspaceTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "completed_ws_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, opening_cash_cents: 10_000)
    @store = @ctx[:store]
    @variant = @ctx[:variant]
    @register_session = @ctx[:register_session]

    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @ctx[:workstation],
      user: @cashier,
      lines: [
        { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 }
      ]
    )
    Pos::RecalculateTransaction.call!(@transaction, business_date: @register_session.business_date)
    complete_pos_sale!(
      transaction: @transaction.reload,
      user: @cashier,
      register_session: @register_session
    )
    @transaction.reload
  end

  test "complete redirects to completed workspace" do
    post pos_transactions_path
    transaction = PosTransaction.order(:id).last
    post add_line_pos_transaction_path(transaction), params: {
      product_variant_id: @variant.id,
      quantity: 1,
      entry_action: "sale"
    }
    transaction.reload
    Pos::RecalculateTransaction.call!(transaction, business_date: @register_session.business_date)
    transaction.pos_tenders.create!(
      tender_type: "cash",
      amount_cents: transaction.total_cents,
      tendered_cents: transaction.total_cents,
      line_number: 1
    )

    patch complete_pos_transaction_path(transaction)

    assert_redirected_to completed_pos_transaction_path(transaction)
  end

  test "completed workspace renders for completed transaction" do
    get completed_pos_transaction_path(@transaction)

    assert_response :success
    assert_includes response.body, "Sale complete".upcase
    assert_includes response.body, @transaction.transaction_number
    assert_includes response.body, "New Sale"
    assert_includes response.body, "View Summary"
    refute_includes response.body, "View receipt"
    refute_includes response.body, "POS home"
    assert_includes response.body, 'data-controller="pos-completed-workspace"'
    assert_select "a[href=?][data-pos-completed-workspace-target='newSaleAction']", pos_root_path, text: "New Sale"
  end

  test "new sale from completed workspace returns to pos home" do
    get completed_pos_transaction_path(@transaction)
    assert_response :success

    get pos_root_path

    assert_response :success
  end

  test "draft transaction cannot view completed workspace" do
    draft = create_pos_transaction!(store: @store, workstation: @ctx[:workstation], user: @cashier)

    get completed_pos_transaction_path(draft)

    assert_redirected_to edit_pos_transaction_path(draft)
  end
end
