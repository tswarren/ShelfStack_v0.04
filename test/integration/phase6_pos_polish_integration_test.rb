# frozen_string_literal: true

require "test_helper"

class Phase6PosPolishIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @cashier = create_user!(username: "cashier")
    @manager = create_user!(username: "manager", pin: "9999")
    grant_all_phase6_permissions!(@cashier, store: @store)
    grant_permission!(@manager, "pos.authorizations.grant", store: @store)
    grant_permission!(@manager, "pos.access", store: @store)

    @variant = create_product_variant!(sku: "POS-POLISH-001", selling_price_cents: 1500)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @cashier, quantity: 5)

    login_user!(@cashier, workstation: @workstation)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @cashier, opening_cash_cents: 10_000)
  end

  test "add line by variant id and complete sale with cash tender sync" do
    post pos_transactions_path, params: { mode: "sale" }
    transaction = PosTransaction.order(:id).last

    post add_line_pos_transaction_path(transaction, mode: "sale"), params: {
      product_variant_id: @variant.id,
      quantity: 1
    }
    assert_redirected_to edit_pos_transaction_path(transaction, mode: "sale")

    transaction.reload
    Pos::RecalculateTransaction.call!(transaction, business_date: @register_session.business_date)
    total = transaction.total_cents

    patch sync_tenders_pos_transaction_path(transaction, mode: "sale"), params: {
      tenders: [{ tender_type: "cash", amount_dollars: format("%.2f", total / 100.0) }]
    }

    patch complete_pos_transaction_path(transaction, mode: "sale"), params: { confirm_inactive: 1 }
    assert_redirected_to pos_transaction_path(transaction)

    transaction.reload
    assert transaction.completed?
    assert_equal "sale", transaction.transaction_type
  end

  test "line lookup presenter returns on hand quantity" do
    get pos_line_lookup_path, params: { q: @variant.sku, mode: "exact" }, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal "found", body["status"]
    assert_equal 5, body["variants"].first["quantity_on_hand"]
  end

  test "receipted partial return respects remaining quantity" do
    sale = create_and_complete_sale!

    post pos_transactions_path, params: { mode: "return" }
    return_txn = PosTransaction.order(:id).last
    source_line = sale.pos_transaction_lines.first

    post add_return_line_pos_transaction_path(return_txn), params: {
      source_transaction_line_id: source_line.id,
      quantity: 1,
      return_disposition: "return_to_stock"
    }

    return_txn.reload
    Pos::RecalculateTransaction.call!(return_txn, business_date: @register_session.business_date)
    total = return_txn.total_cents
    assert total.negative?, "return total should be negative so cash refund reduces drawer"

    patch sync_tenders_pos_transaction_path(return_txn, mode: "return"), params: {
      tenders: [{ tender_type: "cash", amount_dollars: format("%.2f", total / 100.0) }]
    }

    patch complete_pos_transaction_path(return_txn, mode: "return"), params: { confirm_inactive: 1 }
    assert_redirected_to pos_transaction_path(return_txn)
    assert_equal "return", return_txn.reload.transaction_type
  end

  test "no receipt return requires supervisor authorization at complete" do
    post pos_transactions_path, params: { mode: "return" }
    return_txn = PosTransaction.order(:id).last

    post add_line_pos_transaction_path(return_txn, mode: "return"), params: {
      product_variant_id: @variant.id,
      quantity: -1
    }

    return_txn.reload
    Pos::RecalculateTransaction.call!(return_txn, business_date: @register_session.business_date)
    total = return_txn.total_cents
    patch sync_tenders_pos_transaction_path(return_txn, mode: "return"), params: {
      tenders: [{ tender_type: "cash", amount_dollars: format("%.2f", total / 100.0) }]
    }

    patch complete_pos_transaction_path(return_txn, mode: "return"), params: { confirm_inactive: 1 }
    assert_response :redirect
    assert_match %r{/pos/transactions/\d+/edit}, response.redirect_url
    follow_redirect!
    assert_match(/supervisor authorization/i, response.body)

    post pos_authorizations_path, params: {
      authorization_type: "no_receipt_return",
      manager_username: @manager.username,
      manager_pin: "9999",
      pos_transaction_id: return_txn.id
    }, as: :json
    assert_response :success
    authorization_id = response.parsed_body["authorization_id"]

    patch complete_pos_transaction_path(return_txn, mode: "return"), params: {
      confirm_inactive: 1,
      pos_authorization_id: authorization_id
    }
    assert_redirected_to pos_transaction_path(return_txn)
    assert return_txn.reload.completed?
  end

  test "register session summary computes expected closing cash" do
    sale = create_and_complete_sale!
    summary = Pos::RegisterSessionSummary.for(@register_session)

    assert_equal 10_000, summary.opening_cash_cents
    assert summary.expected_closing_cash_cents >= 10_000
    assert_equal 1, summary.completed_transaction_count
    assert sale.completed?
  end

  test "sales report exports csv" do
    create_and_complete_sale!
    get sales_pos_reports_path(format: :csv)
    assert_response :success
    assert_match "transaction_number", response.body
  end

  private

  def create_and_complete_sale!
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
    transaction.reload
  end
end
