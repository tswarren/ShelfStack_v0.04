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
      quantity: 1,
      entry_action: "sale"
    }
    assert_redirected_to edit_pos_transaction_path(transaction)

    transaction.reload
    Pos::RecalculateTransaction.call!(transaction, business_date: @register_session.business_date)
    total = transaction.total_cents

    patch complete_pos_transaction_path(transaction, mode: "sale"), params: {
      confirm_inactive: 1,
      tenders: [{ tender_type: "cash", amount_dollars: format("%.2f", total / 100.0) }]
    }
    assert_redirected_to pos_transaction_path(transaction)

    transaction.reload
    assert transaction.completed?
    assert_equal "sale", transaction.transaction_type

    follow_redirect!
    assert_response :success
    assert_match(/View receipt/i, response.body)
    assert_match(/New sale/i, response.body)
    assert_match(/Void transaction/i, response.body)
    refute_match(/Change due/i, response.body)
  end

  test "completed sale show page highlights change due when cash overpaid" do
    post pos_transactions_path, params: { mode: "sale" }
    transaction = PosTransaction.order(:id).last

    post add_line_pos_transaction_path(transaction, mode: "sale"), params: {
      product_variant_id: @variant.id,
      quantity: 1,
      entry_action: "sale"
    }

    transaction.reload
    Pos::RecalculateTransaction.call!(transaction, business_date: @register_session.business_date)
    total = transaction.total_cents

    patch complete_pos_transaction_path(transaction, mode: "sale"), params: {
      confirm_inactive: 1,
      tenders: [{ tender_type: "cash", amount_dollars: format("%.2f", (total + 500) / 100.0) }]
    }
    assert_redirected_to pos_transaction_path(transaction)

    follow_redirect!
    assert_response :success
    assert_match(/Change due/i, response.body)
    assert_match(/\$5\.00/, response.body)
    assert_match(/View receipt/i, response.body)
    assert_match(/New sale/i, response.body)
  end

  test "update line unit price on scanned cart line" do
    post pos_transactions_path, params: { mode: "sale" }
    transaction = PosTransaction.order(:id).last

    post add_line_pos_transaction_path(transaction, mode: "sale"), params: {
      product_variant_id: @variant.id,
      quantity: 1,
      entry_action: "sale"
    }

    line = transaction.reload.pos_transaction_lines.first
    assert_equal 1500, line.unit_price_cents

    patch update_line_pos_transaction_path(transaction), params: {
      line_id: line.id,
      unit_price: "12.50"
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success

    line.reload
    assert_equal 1250, line.unit_price_cents
    assert_equal 1250, line.extended_price_cents
    assert_operator transaction.reload.total_cents, :>, 0
  end

  test "open ring line respects return mode checkbox" do
    post pos_transactions_path, params: { mode: "return" }
    transaction = PosTransaction.order(:id).last
    sub_department = @variant.sub_department

    post add_open_ring_line_pos_transaction_path(transaction), params: {
      description: "Gift wrap return",
      sub_department_id: sub_department.id,
      unit_price: "5.00",
      quantity: 1,
      return_mode: "1"
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success

    line = transaction.reload.pos_transaction_lines.first
    assert line.open_ring_line?
    assert_equal(-1, line.quantity)
    assert_equal "return_to_stock", line.return_disposition
    assert_operator transaction.total_cents, :<, 0
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

    patch complete_pos_transaction_path(return_txn, mode: "return"), params: {
      confirm_inactive: 1,
      tenders: [{ tender_type: "cash", amount_dollars: format("%.2f", total / 100.0) }]
    }
    assert_redirected_to pos_transaction_path(return_txn)
    assert_equal "return", return_txn.reload.transaction_type

    get pos_return_lookup_path, params: { transaction_number: sale.transaction_number }, as: :json
    assert_response :success
    body = response.parsed_body
    line = body["lines"].sole
    assert_equal 0, line["remaining_quantity"]
    refute line["returnable"]

    get pos_return_lookup_path, params: { transaction_number: return_txn.transaction_number }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal sale.transaction_number, body["transaction"]["transaction_number"]
    line = body["lines"].sole
    assert_equal 0, line["remaining_quantity"]
    refute line["returnable"]
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
    patch complete_pos_transaction_path(return_txn, mode: "return"), params: {
      confirm_inactive: 1,
      tenders: [{ tender_type: "cash", amount_dollars: format("%.2f", total / 100.0) }]
    }
    assert_response :redirect
    assert_match %r{/pos/transactions/\d+/edit}, response.redirect_url
    follow_redirect!
    assert_match(/supervisor authorization/i, response.body)
    assert_match(/Manager sign-in/i, response.body)

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
      pos_authorization_id: authorization_id,
      tenders: [{ tender_type: "cash", amount_dollars: format("%.2f", return_txn.total_cents / 100.0) }]
    }
    assert_redirected_to pos_transaction_path(return_txn)
    assert return_txn.reload.completed?
  end

  test "no receipt return edit shows authorize button when blocked" do
    post pos_transactions_path, params: { mode: "return" }
    return_txn = PosTransaction.order(:id).last

    post add_line_pos_transaction_path(return_txn, mode: "return"), params: {
      product_variant_id: @variant.id,
      quantity: -1
    }

    return_txn.reload
    Pos::RecalculateTransaction.call!(return_txn, business_date: @register_session.business_date)

    get edit_pos_transaction_path(return_txn, mode: "return")
    assert_response :success
    assert_match(/Manager sign-in/i, response.body)
    assert_match(/No-receipt return requires manager approval/i, response.body)
  end

  test "no receipt return authorization persists after line changes without param id" do
    post pos_transactions_path, params: { mode: "return" }
    return_txn = PosTransaction.order(:id).last

    post add_line_pos_transaction_path(return_txn, mode: "return"), params: {
      product_variant_id: @variant.id,
      quantity: -1
    }

    post pos_authorizations_path, params: {
      authorization_type: "no_receipt_return",
      manager_username: @manager.username,
      manager_pin: "9999",
      pos_transaction_id: return_txn.id
    }, as: :json
    assert_response :success

    post add_line_pos_transaction_path(return_txn, mode: "return"), params: {
      product_variant_id: @variant.id,
      quantity: -1,
      entry_action: "return_no_receipt"
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success

    return_txn.reload
    readiness = Pos::CompletionReadiness.check(
      transaction: return_txn,
      register_session: @register_session
    )

    refute readiness.structural_blockers.any? { |check| check.key == :no_receipt_return && check.status == :block }
    assert readiness.checks.any? { |check| check.key == :no_receipt_return && check.status == :ok }
  end

  test "completes even exchange with zero cash tender sync" do
    post pos_transactions_path, params: { mode: "exchange" }
    exchange_txn = PosTransaction.order(:id).last

    post add_line_pos_transaction_path(exchange_txn, mode: "sale"), params: {
      product_variant_id: @variant.id,
      quantity: 1,
      entry_action: "sale"
    }
    post add_line_pos_transaction_path(exchange_txn, mode: "return"), params: {
      product_variant_id: @variant.id,
      quantity: -1,
      entry_action: "return_no_receipt"
    }

    exchange_txn.reload
    Pos::RecalculateTransaction.call!(exchange_txn, business_date: @register_session.business_date)
    assert exchange_txn.total_cents.zero?

    post pos_authorizations_path, params: {
      authorization_type: "no_receipt_return",
      manager_username: @manager.username,
      manager_pin: "9999",
      pos_transaction_id: exchange_txn.id
    }, as: :json
    assert_response :success

    patch complete_pos_transaction_path(exchange_txn, mode: "exchange"), params: {
      confirm_inactive: 1,
      tenders: [{ tender_type: "cash", amount_dollars: "0.00" }]
    }
    assert_redirected_to pos_transaction_path(exchange_txn)

    exchange_txn.reload
    assert exchange_txn.completed?
    assert_equal "exchange", exchange_txn.transaction_type
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
