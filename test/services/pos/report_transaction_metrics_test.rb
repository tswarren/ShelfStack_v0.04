# frozen_string_literal: true

require "test_helper"

class Pos::ReportTransactionMetricsTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(selling_price_cents: 1000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    @session = open_register_session!(store: @store, workstation: @workstation, user: @user, opening_cash_cents: 5000)
  end

  test "discounted return reports net refund without duplicate discount" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ {
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        line_discount_cents: 100,
        extended_price_cents: 900
      } ]
    )
    Pos::RecalculateTransaction.call!(sale, business_date: @session.business_date)
    complete_pos_sale!(transaction: sale, user: @user, register_session: @session)
    sale_metrics = Pos::ReportTransactionMetrics.from_transaction(sale.reload)

    assert_equal 1000, sale_metrics.sales_cents
    assert_equal 0, sale_metrics.refunds_cents
    assert_equal 100, sale_metrics.line_discount_cents
    assert_equal 900, sale_metrics.net_sales_cents

    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ {
        product_variant: @variant,
        quantity: -1,
        unit_price_cents: 1000,
        extended_price_cents: -900,
        return_disposition: "return_to_stock",
        source_transaction_line: sale.pos_transaction_lines.first
      } ]
    )
    Pos::RecalculateTransaction.call!(return_txn, business_date: @session.business_date)
    return_metrics = Pos::ReportTransactionMetrics.from_transaction(return_txn.reload)

    assert_equal 0, return_metrics.sales_cents
    assert_equal(-900, return_metrics.refunds_cents)
    assert_equal 0, return_metrics.line_discount_cents
    assert_equal 0, return_metrics.order_discount_cents
    assert_equal(-900, return_metrics.net_sales_cents)

    combined = Pos::ReportTransactionMetrics.combine([ sale_metrics, return_metrics ])
    assert_equal 1000, combined.sales_cents
    assert_equal(-900, combined.refunds_cents)
    assert_equal 100, combined.line_discount_cents
    assert_equal 0, combined.net_sales_cents
  end
end
