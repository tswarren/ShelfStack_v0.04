# frozen_string_literal: true

require "test_helper"

class PosTransactionConfirmationTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @cashier = create_user!(username: "confirm_cashier")
    grant_all_phase6_permissions!(@cashier, store: @store)

    @variant = create_product_variant!(sku: "CONF-SKU-001", selling_price_cents: 1500)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @cashier, quantity: 5)

    login_user!(@cashier, workstation: @workstation)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @cashier)
  end

  test "completed sale shows confirmation layout with actions summary and footer void" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [{
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1500,
        extended_price_cents: 1500
      }]
    )
    Pos::RecalculateTransaction.call!(transaction, business_date: @register_session.business_date)
    total = transaction.total_cents

    complete_pos_sale!(
      transaction: transaction.reload,
      user: @cashier,
      register_session: @register_session,
      tenders: [{ tender_type: "cash", amount_cents: total, reference_number: "tendered_cents:#{total + 500}" }]
    )

    get pos_transaction_path(transaction.reload)
    assert_response :success

    assert_match "POS Menu", response.body
    assert_match "Receipt", response.body
    assert_match "New Transaction", response.body
    assert_select "a[href=?]", pos_root_path, text: "POS Menu"
    assert_select "a[href=?]", pos_receipt_path(transaction.pos_receipt), text: "Receipt"
    assert_select ".ss-pos-confirmation__change", text: /Change due/
    assert_select "dt", text: "Total due"
    assert_select "dt", text: "Items sold"
    assert_select "dt", text: "Items returned"
    assert_select ".ss-pos-panel__title", text: "Lines"
    assert_select ".ss-pos-confirmation__void button", text: "Void transaction"
    assert_no_match "Back to POS", response.body
    assert_select ".ss-pos-transaction-show__header button", count: 0
  end

  test "new transaction button creates draft sale" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [{
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1500,
        extended_price_cents: 1500
      }]
    )
    complete_pos_sale!(transaction: transaction, user: @cashier, register_session: @register_session)

    assert_difference -> { PosTransaction.drafts.count }, 1 do
      post pos_transactions_path, params: { mode: "sale" }
    end
    assert_redirected_to edit_pos_transaction_path(PosTransaction.order(:id).last, mode: "sale")
  end
end
