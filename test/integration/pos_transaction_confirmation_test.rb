# frozen_string_literal: true

require "test_helper"

class PosTransactionConfirmationTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "confirm_cashier")
    @ctx = setup_pos_workstation!(user: @cashier)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @variant = @ctx[:variant]
    @register_session = @ctx[:register_session]
  end

  test "completed sale shows confirmation layout with actions summary and footer void" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [ {
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1500,
        extended_price_cents: 1500
      } ]
    )
    Pos::RecalculateTransaction.call!(transaction, business_date: @register_session.business_date)
    total = transaction.total_cents

    complete_pos_sale!(
      transaction: transaction.reload,
      user: @cashier,
      register_session: @register_session,
      tenders: [ { tender_type: "cash", amount_cents: total, reference_number: "tendered_cents:#{total + 500}" } ]
    )

    get pos_transaction_path(transaction.reload)
    assert_response :success

    assert_match "POS Menu", response.body
    assert_match "Receipt", response.body
    refute_match "New Transaction", response.body
    assert_select "a[href=?]", pos_root_path, text: "POS Menu"
    assert_select "a[href=?]", pos_receipt_path(transaction.pos_receipt), text: "Receipt"
    assert_select ".ss-pos-transaction-show__primary-action", text: "POS Menu"
    assert_select ".ss-pos-transaction-show__secondary-action", text: "Receipt"
    assert_select ".ss-pos-transaction-show__actions"
    assert_select ".ss-pos-transaction-show__eyebrow", text: "SALE COMPLETE"
    assert_select "h1.ss-pos-transaction-show__title", text: "Transaction #{transaction.transaction_number}"
    assert_select ".ss-pos-confirmation__change", text: /Change due/
    assert_select "dt", text: "Total due"
    assert_select "dt", text: "Items sold"
    assert_select "dt", text: "Items returned"
    assert_select ".ss-pos-panel__title", text: "Lines"
    assert_select ".ss-pos-confirmation__void button", text: "Void transaction"
    assert_no_match "Back to POS", response.body
    assert_select ".ss-pos-transaction-show__header button", count: 0
  end

  test "voided transaction shows summary layout with pos menu" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [ {
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1500,
        extended_price_cents: 1500
      } ]
    )
    complete_pos_sale!(transaction: transaction.reload, user: @cashier, register_session: @register_session)

    authorization = grant_void_authorization!(transaction: transaction, requested_by: @cashier)
    patch void_pos_transaction_path(transaction), params: {
      reason_code: "cashier_error",
      pos_authorization_id: authorization.id
    }

    get pos_transaction_path(transaction.reload)
    assert_response :success

    assert_select ".ss-pos-transaction-show--summary"
    assert_select ".ss-pos-transaction-show__eyebrow", text: "TRANSACTION VOIDED"
    assert_select "a[href=?]", pos_root_path, text: "POS Menu"
    assert_select ".ss-pos-transaction-show__void-notice", text: /This transaction was voided/
    assert_select ".ss-pos-confirmation__void", count: 0
    refute_match "Status: Voided", response.body
  end

  test "new transaction button creates draft sale" do
    transaction = create_completed_pos_sale!(
      user: @cashier,
      register_session: @register_session,
      variant: @variant,
      store: @store,
      workstation: @workstation
    )

    assert transaction.completed?

    assert_difference -> { PosTransaction.drafts.count }, 1 do
      post pos_transactions_path, params: { mode: "sale" }
    end
    assert_redirected_to edit_pos_transaction_path(PosTransaction.order(:id).last, mode: "sale")
  end
end
