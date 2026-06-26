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
    @rate = create_store_tax_rate!(store: @store, tax_rate_bps: 600)
    create_store_tax_category_rate!(store: @store, tax_category: @tax_category, store_tax_rate: @rate)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 2)
  end

  test "groups tax by category rate and source on completed lines" do
    create_completed_pos_sale!(
      user: @user,
      register_session: @session,
      variant: @variant,
      store: @store,
      workstation: @workstation
    )

    scope = Pos::ReportScope.from_params(
      store: @store,
      params: { filter_type: "business_date", business_date: @session.business_date.to_s }
    )

    result = Reports::TaxCollected::Query.call(scope: scope)
    detail_rows = result.rows.select { |row| row.row_type == :detail }

    assert_equal 60, result.total_tax_cents
    assert_equal 1, detail_rows.size
    assert_includes detail_rows.first.label, @tax_category.name
    assert_includes detail_rows.first.label, "6.00%"
    assert_includes detail_rows.first.label, "Normal"
    assert_equal 1000, detail_rows.first.taxable_sales_cents
    assert_equal 60, detail_rows.first.normal_tax_cents
    assert_equal 60, detail_rows.first.tax_cents
    assert_equal 0, detail_rows.first.exempt_overridden_cents
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
        store_tax_rate_id: @rate.id
      } ]
    )

    scope = Pos::ReportScope.from_params(
      store: @store,
      params: { filter_type: "business_date", business_date: @session.business_date.to_s }
    )

    result = Reports::TaxCollected::Query.call(scope: scope)

    assert_equal 0, result.total_tax_cents
  end
end
