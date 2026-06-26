# frozen_string_literal: true

require "test_helper"

class Reports::TaxCollectedQueryTest < ActiveSupport::TestCase
  include Phase1TestHelper
  include Phase6TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "taxquery#{SecureRandom.hex(3)}")
    @session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    @variant = create_product_variant!(selling_price_cents: 1000)
    @tax_category = @variant.sub_department.default_tax_category
    @rate = create_store_tax_rate!(store: @store, name: "MI Sales Tax", short_name: "MI Sales Tax", tax_rate_bps: 600)
    create_store_tax_category_rate!(store: @store, tax_category: @tax_category, store_tax_rate: @rate)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 2)
    @reason = TaxExceptionReason.create!(
      reason_key: "resale-#{SecureRandom.hex(3)}",
      name: "Resale Certificate",
      exception_type: "exemption",
      requires_certificate: true
    )
  end

  test "rolls up actual tax by snapshot rate and category" do
    create_completed_pos_sale!(
      user: @user,
      register_session: @session,
      variant: @variant,
      store: @store,
      workstation: @workstation
    )

    result = call_query
    detail_row = result.rate_rows.find { |row| row.row_type == :detail }

    assert_equal 60, result.total_tax_cents
    assert_includes detail_row.label, "MI Sales Tax"
    assert_includes detail_row.label, "6.00%"
    assert_includes detail_row.label, @tax_category.name
    assert_equal 1000, detail_row.sales_cents
    assert_equal 0, detail_row.returns_cents
    assert_equal 1000, detail_row.net_taxable_sales_cents
    assert_equal 60, detail_row.tax_collected_cents
    assert_equal 0, detail_row.tax_refunded_cents
    assert_equal 60, detail_row.net_tax_cents
    assert_equal 1000, summary_value(result, "Net taxable sales")
    assert_equal 60, summary_value(result, "Net tax collected")
  end

  test "puts exemptions in adjustment section not rate totals" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000, line_type: "variant" } ]
    )
    Pos::RecalculateTransaction.call!(transaction, business_date: @session.business_date)
    Pos::TaxExceptionApplicationService.call!(
      transaction: transaction,
      scope: "transaction",
      tax_exception_reason: @reason,
      certificate_number: "MI-123456",
      actor: @user
    )
    complete_pos_sale!(transaction: transaction, user: @user, register_session: @session)

    result = call_query
    rate_detail = result.rate_rows.find { |row| row.row_type == :detail }
    adjustment = result.adjustment_rows.find { |row| row.label == "Tax-exempt transaction" }

    assert_equal 0, result.total_tax_cents
    assert_equal 1000, rate_detail.net_taxable_sales_cents
    assert_equal 0, rate_detail.net_tax_cents
    assert_equal 1, adjustment.line_count
    assert_equal 60, adjustment.normal_tax_cents
    assert_equal 0, adjustment.actual_tax_cents
    assert_equal 60, adjustment.difference_cents
    assert_equal 60, summary_value(result, "Exempt / overridden tax")
  end

  test "excludes draft transactions from tax totals" do
    create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      attrs: {
        status: "draft",
        transaction_type: "sale",
        business_date: @session.business_date
      },
      lines: [ {
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        extended_price_cents: 1000,
        tax_cents: 60,
        normal_tax_cents: 60,
        applied_tax_source: "normal",
        tax_category_id: @tax_category.id,
        store_tax_rate_id: @rate.id,
        tax_rate_bps: 600,
        store_tax_rate_short_name_snapshot: "MI Sales Tax"
      } ]
    )

    result = call_query

    assert_equal 0, result.total_tax_cents
    assert_nil result.rate_rows.find { |row| row.row_type == :detail }
  end

  private

  def call_query
    scope = Pos::ReportScope.from_params(
      store: @store,
      params: { filter_type: "business_date", business_date: @session.business_date.to_s }
    )

    Reports::TaxCollected::Query.call(scope: scope)
  end

  def summary_value(result, label)
    metric = result.summary_metrics.find { |entry| entry[:label] == label }
    metric[:value_cents] || metric[:value]
  end
end
