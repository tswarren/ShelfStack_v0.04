# frozen_string_literal: true

require "test_helper"

class Pos::SalesRegisterSummaryReportTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @cashier = create_user!(username: "register_cashier", display_name: "Cathy")
    @variant = create_product_variant!(selling_price_cents: 2000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @cashier, quantity: 10)
    @session = open_register_session!(store: @store, workstation: @workstation, user: @cashier, opening_cash_cents: 10_000)
    @scope = Pos::ReportScope.new(
      type: :register_session,
      store: @store,
      register_session: @session,
      label: "test"
    )
  end

  test "builds compact revenue payment drawer and breakdown sections" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: { discount_cents: 200 },
      lines: [{
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 2000,
        line_discount_cents: 100,
        extended_price_cents: 1700
      }]
    )
    Pos::RecalculateTransaction.call!(sale, business_date: @session.business_date)
    complete_pos_sale!(transaction: sale, user: @cashier, register_session: @session)

    report = Pos::SalesRegisterSummaryReport.call(scope: @scope)

    assert_equal 2000, report.revenue.gross_sales_cents
    assert_equal(-100, report.revenue.line_discount_cents)
    assert_equal(-200, report.revenue.order_discount_cents)
    assert report.payments.any? { |row| row.label == "Cash sales" && row.amount_cents.positive? }
    assert report.transaction_mix.any? { |row| row.label == "Units sold" && row.units_sold == 1 }
    assert report.drawer.available
    assert_equal 10_000, report.drawer.starting_bank_cents
    assert_equal "Cathy", report.by_clerk.sole.label
    assert_equal 1, report.breakdown_total.transaction_count
    assert_equal 0, report.exceptions.void_count
  end

  test "requires register session scope" do
    scope = Pos::ReportScope.new(
      type: :business_date,
      store: @store,
      business_date: Date.current,
      label: "test"
    )

    assert_raises(ArgumentError) do
      Pos::SalesRegisterSummaryReport.call(scope: scope)
    end
  end

  test "groups hourly breakdown by store time zone" do
    @store.update!(time_zone: "America/New_York")

    sale = nil
    travel_to Time.utc(2026, 1, 15, 18, 30, 0) do
      sale = create_pos_transaction!(
        store: @store,
        workstation: @workstation,
        user: @cashier,
        lines: [{
          product_variant: @variant,
          quantity: 1,
          unit_price_cents: 2000,
          extended_price_cents: 2000
        }]
      )
      complete_pos_sale!(transaction: sale, user: @cashier, register_session: @session)
    end

    report = Pos::SalesRegisterSummaryReport.call(scope: @scope)
    hour_rows = report.by_hour.reject { |row| row.label == "Total" }

    assert_equal 1, hour_rows.size
    assert_equal "1pm–2pm", hour_rows.first.label
  end
end
