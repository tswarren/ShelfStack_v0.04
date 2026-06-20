# frozen_string_literal: true

require "test_helper"

class PosRegisterCloseTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @cashier = create_user!(username: "close_cashier")
    grant_all_phase6_permissions!(@cashier, store: @store)

    @variant = create_product_variant!(selling_price_cents: 2000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @cashier, quantity: 5)

    login_user!(@cashier, workstation: @workstation)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @cashier, opening_cash_cents: 5000)

    post pos_transactions_path
    transaction = PosTransaction.order(:id).last
    post add_line_pos_transaction_path(transaction), params: {
      product_variant_id: @variant.id,
      quantity: 1,
      entry_action: "sale"
    }
    transaction.reload
    Pos::RecalculateTransaction.call!(transaction, business_date: @register_session.business_date)
    complete_pos_sale!(transaction: transaction, user: @cashier, register_session: @register_session)
  end

  test "close ignores tampered expected cash and stores computed summary value" do
    summary = Pos::RegisterSessionSummary.for(@register_session)
    counted_cents = summary.expected_closing_cash_cents + 100

    patch close_pos_register_session_path(@register_session), params: {
      expected_closing_cash_dollars: "9999.99",
      counted_closing_cash_dollars: format("%.2f", counted_cents / 100.0)
    }

    assert_redirected_to pos_root_path
    @register_session.reload

    assert_equal summary.expected_closing_cash_cents, @register_session.expected_closing_cash_cents
    assert_equal counted_cents, @register_session.counted_closing_cash_cents
    assert_equal 100, @register_session.counted_closing_cash_cents - @register_session.expected_closing_cash_cents
    assert_equal "closed", @register_session.status
  end
end
