# frozen_string_literal: true

require "test_helper"

class Pos::SalesRevenueSummaryReportTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @cashier = create_user!(username: "summary_cashier", display_name: "Cathy")
    @manager = create_user!(username: "summary_manager", display_name: "Administrator")
    @variant = create_product_variant!(selling_price_cents: 2000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @cashier, quantity: 10)
    @session = open_register_session!(store: @store, workstation: @workstation, user: @cashier, opening_cash_cents: 10_000)
  end

  test "aggregates gross sales discounts taxes and net sales for session scope" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: { discount_cents: 200 },
      lines: [ {
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 2000,
        line_discount_cents: 100,
        extended_price_cents: 1700
      } ]
    )
    Pos::RecalculateTransaction.call!(sale, business_date: @session.business_date)
    complete_pos_sale!(transaction: sale, user: @cashier, register_session: @session)

    scope = Pos::ReportScope.new(
      type: :register_session,
      store: @store,
      register_session: @session,
      label: "test"
    )
    report = Pos::SalesRevenueSummaryReport.call(scope: scope)

    assert_equal 2000, report.revenue_summary.gross_sales_cents
    assert_equal(-300, report.revenue_summary.discounts_cents)
    assert report.revenue_summary.taxes_cents.positive?
    assert_equal 1, report.revenue_summary.transaction_count
    assert_equal "Cathy", report.by_clerk.sole.clerk_name
    assert report.by_tender.any? { |row| row.tender_type == "cash" && row.amount_cents.positive? }
    assert report.drawer.available
    assert_equal 10_000, report.drawer.starting_bank_cents
  end

  test "includes refunds and void counts" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 2000, extended_price_cents: 2000 } ]
    )
    complete_pos_sale!(transaction: sale, user: @cashier, register_session: @session)

    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @manager,
      lines: [ {
        product_variant: @variant,
        quantity: -1,
        unit_price_cents: 2000,
        extended_price_cents: -2000,
        return_disposition: "return_to_stock",
        source_transaction_line: sale.pos_transaction_lines.first
      } ]
    )
    Pos::RecalculateTransaction.call!(return_txn, business_date: @session.business_date)
    create_pos_tender!(return_txn, tender_type: "cash", amount_cents: return_txn.total_cents)
    complete_pos_transaction!(
      transaction: return_txn.reload,
      completed_by_user: @manager,
      register_session: @session,
      confirmed_inactive: true
    )

    authorization = grant_void_authorization!(transaction: sale.reload, requested_by: @manager)
    Pos::VoidTransaction.call!(
      transaction: sale.reload,
      voided_by_user: @manager,
      register_session: @session,
      reason_code: "cashier_error",
      pos_authorization: authorization
    )

    scope = Pos::ReportScope.new(
      type: :register_session,
      store: @store,
      register_session: @session,
      label: "test"
    )
    report = Pos::SalesRevenueSummaryReport.call(scope: scope)

    assert_operator report.revenue_summary.refunds_cents, :<, 0
    assert_equal 1, report.revenue_summary.void_count
    assert_equal report.by_hour.reject { |row| row.label == "Total" }.sum { |row| row.metrics.void_count },
                 report.by_hour.find { |row| row.label == "Total" }.metrics.void_count
    assert_equal 1, report.by_clerk.size
    assert_equal "Administrator", report.by_clerk.sole.clerk_name
  end

  test "business date scope selects transactions for that date" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1500, extended_price_cents: 1500 } ]
    )
    complete_pos_sale!(transaction: sale, user: @cashier, register_session: @session)

    scope = Pos::ReportScope.new(
      type: :business_date,
      store: @store,
      business_date: @session.business_date,
      label: "test"
    )
    report = Pos::SalesRevenueSummaryReport.call(scope: scope)

    assert_equal 1, report.revenue_summary.transaction_count
    assert_equal 1500, report.revenue_summary.gross_sales_cents
    refute report.drawer.available
  end
end
