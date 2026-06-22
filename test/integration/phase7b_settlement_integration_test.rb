# frozen_string_literal: true

require "test_helper"

class Phase7bSettlementIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase6_permissions!(@user, store: @store)
    @variant = create_product_variant!(selling_price_cents: 2000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 10)
    login_user!(@user, workstation: @workstation)
    @session = open_register_session!(store: @store, workstation: @workstation, user: @user, opening_cash_cents: 5000)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 2000, extended_price_cents: 2000 } ]
    )
    Pos::RecalculateTransaction.call!(@transaction, business_date: @session.business_date)
  end

  test "multi-card sale completes through settlement sync" do
    third = @transaction.total_cents / 3
    remainder = @transaction.total_cents - (third * 2)

    Pos::SettlementSync.call!(
      transaction: @transaction,
      tender_inputs: [
        { tender_type: "card", amount_cents: third, card_brand: "visa", card_last_four: "1111" },
        { tender_type: "card", amount_cents: third, card_brand: "mastercard", card_last_four: "2222" },
        { tender_type: "check", amount_cents: remainder, check_number: "9001" }
      ],
      actor: @user
    )

    Pos::CompleteTransaction.call!(
      transaction: @transaction.reload,
      completed_by_user: @user,
      register_session: @session,
      confirmed_inactive: true
    )

    @transaction.reload
    assert @transaction.completed?
    assert_equal 3, @transaction.pos_tenders.settlement_rows.count
    assert_equal @transaction.total_cents, @transaction.pos_tenders.settlement_rows.sum(&:amount_cents)
  end

  test "split refund completes" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: -1, unit_price_cents: 2000, extended_price_cents: -2000 } ]
    )
    Pos::RecalculateTransaction.call!(return_txn, business_date: @session.business_date)
    half = return_txn.total_cents.abs / 2
    remaining = return_txn.total_cents - (-half)

    grant_no_receipt_return_authorization!(return_txn, requested_by: @user)

    Pos::SettlementSync.call!(
      transaction: return_txn,
      tender_inputs: [
        { tender_type: "card", amount_cents: -half, card_brand: "visa" },
        { tender_type: "cash", amount_cents: remaining }
      ],
      actor: @user
    )

    Pos::CompleteTransaction.call!(
      transaction: return_txn.reload,
      completed_by_user: @user,
      register_session: @session,
      confirmed_inactive: true
    )

    return_txn.reload
    assert return_txn.completed?
    assert_equal return_txn.total_cents, return_txn.pos_tenders.settlement_rows.sum(&:amount_cents)
  end

  test "edit page renders settlement modal launcher instead of inline panel" do
    get edit_pos_transaction_path(@transaction)
    assert_response :success
    assert_select "#pos_settlement_modal[hidden]"
    assert_select "#pos_settlement_actions .ss-pos-settlement-open-btn"
    assert_select "#pos_tender_panel", false
    assert_select "details.ss-pos-adjustments summary", text: "Discount/Adjustment"
    assert_select "#pos_settlement_actions .ss-pos-secondary-actions--inline"
  end

  test "complete sale via settlements params matching modal form" do
    total = @transaction.total_cents
    half = total / 2

    patch complete_pos_transaction_path(@transaction), params: {
      confirm_inactive: 1,
      settlements: [
        { tender_type: "card", amount_dollars: format("%.2f", half / 100.0), card_brand: "visa", card_last_four: "4242" },
        { tender_type: "cash", tendered_dollars: format("%.2f", (total - half) / 100.0) }
      ]
    }
    assert_redirected_to pos_transaction_path(@transaction)

    @transaction.reload
    assert @transaction.completed?
    assert_equal 2, @transaction.pos_tenders.settlement_rows.count
  end

  test "void preserves reversal line numbers and receipt fields" do
    half = @transaction.total_cents / 2

    Pos::SettlementSync.call!(
      transaction: @transaction,
      tender_inputs: [
        { tender_type: "card", amount_cents: half, card_brand: "visa", card_last_four: "9999" },
        { tender_type: "check", amount_cents: @transaction.total_cents - half, check_number: "1234" }
      ],
      actor: @user
    )
    Pos::CompleteTransaction.call!(
      transaction: @transaction.reload,
      completed_by_user: @user,
      register_session: @session,
      confirmed_inactive: true
    )

    original_line_numbers = @transaction.pos_tenders.settlement_rows.pluck(:line_number)
    authorization = grant_void_authorization!(transaction: @transaction.reload, requested_by: @user)
    Pos::VoidTransaction.call!(
      transaction: @transaction.reload,
      voided_by_user: @user,
      register_session: @session,
      reason_code: "cashier_error",
      pos_authorization: authorization
    )

    reversals = @transaction.pos_tenders.where.not(reverses_tender_id: nil)
    assert_equal 2, reversals.count
    reversals.each do |reversal|
      refute_includes original_line_numbers, reversal.line_number
    end
  end
end
