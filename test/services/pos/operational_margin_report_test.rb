# frozen_string_literal: true

require "test_helper"

class Pos::OperationalMarginReportTest < ActiveSupport::TestCase
  include Phase6TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase6_permissions!(@user, store: @store)
    @variant = create_product_variant!(selling_price_cents: 1500)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 5, unit_cost_cents: 700)
    @session = open_register_session!(store: @store, workstation: @workstation, user: @user)
  end

  test "includes completed sale margin using cogs snapshots" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1500, extended_price_cents: 1500 } ]
    )
    complete_pos_sale!(transaction: sale, user: @user, register_session: @session)

    scope = Pos::ReportScope.from_params(store: @store, params: { register_session_id: @session.id })
    report = Pos::OperationalMarginReport.call(scope: scope)

    assert_equal 1500, report.net_revenue_cents
    assert_equal 700, report.total_cogs_cents
    assert_equal 800, report.actual_margin_cents
    assert_equal 0, report.estimated_margin_cents
  end

  test "excludes voided transactions" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1500, extended_price_cents: 1500 } ]
    )
    complete_pos_sale!(transaction: sale, user: @user, register_session: @session)
    authorization = grant_void_authorization!(transaction: sale, requested_by: @user)
    Pos::VoidTransaction.call!(
      transaction: sale,
      voided_by_user: @user,
      register_session: @session,
      reason_code: "cashier_error",
      pos_authorization: authorization
    )

    scope = Pos::ReportScope.from_params(store: @store, params: { register_session_id: @session.id })
    report = Pos::OperationalMarginReport.call(scope: scope)

    assert_equal 0, report.net_revenue_cents
    assert_equal 0, report.total_cogs_cents
  end

  test "net revenue uses signed extended price after line discount" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        {
          product_variant: @variant,
          quantity: 1,
          unit_price_cents: 2000,
          line_discount_cents: 500,
          extended_price_cents: 1500
        }
      ]
    )
    complete_pos_sale!(transaction: sale, user: @user, register_session: @session)

    scope = Pos::ReportScope.from_params(store: @store, params: { register_session_id: @session.id })
    report = Pos::OperationalMarginReport.call(scope: scope)

    assert_equal 1500, report.net_revenue_cents
  end

  test "net revenue uses signed extended price after transaction discount" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      attrs: { discount_cents: 300 },
      lines: [
        { product_variant: @variant, quantity: 1, unit_price_cents: 2000, line_discount_cents: 0, extended_price_cents: 2000 }
      ]
    )
    complete_pos_sale!(transaction: sale, user: @user, register_session: @session)

    scope = Pos::ReportScope.from_params(store: @store, params: { register_session_id: @session.id })
    report = Pos::OperationalMarginReport.call(scope: scope)

    assert_equal 1700, report.net_revenue_cents
  end

  test "sourced return subtracts net revenue and reverses cogs" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1500, extended_price_cents: 1500 } ]
    )
    complete_pos_sale!(transaction: sale, user: @user, register_session: @session)
    source_line = sale.pos_transaction_lines.first

    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        {
          product_variant: @variant,
          quantity: -1,
          unit_price_cents: 1500,
          extended_price_cents: 1500,
          source_transaction_line_id: source_line.id
        }
      ]
    )
    complete_pos_sale!(transaction: return_txn, user: @user, register_session: @session)

    scope = Pos::ReportScope.from_params(store: @store, params: { register_session_id: @session.id })
    report = Pos::OperationalMarginReport.call(scope: scope)

    assert_equal 0, report.net_revenue_cents
    assert_equal 0, report.total_cogs_cents
    assert_equal 0, report.actual_margin_cents
  end

  test "blind return subtracts net revenue" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1500, extended_price_cents: 1500 } ]
    )
    complete_pos_sale!(transaction: sale, user: @user, register_session: @session)

    blind_return = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        { product_variant: @variant, quantity: -1, unit_price_cents: 1500, extended_price_cents: 1500 }
      ]
    )
    grant_no_receipt_return_authorization!(blind_return, requested_by: @user)
    complete_pos_sale!(transaction: blind_return, user: @user, register_session: @session)

    scope = Pos::ReportScope.from_params(store: @store, params: { register_session_id: @session.id })
    report = Pos::OperationalMarginReport.call(scope: scope)

    assert_equal 0, report.net_revenue_cents
  end

  test "unknown cost revenue is excluded from estimated margin" do
    @variant.sub_department.update!(default_margin_target_bps: nil)
    InventoryBalance.where(store: @store, product_variant: @variant).delete_all

    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1500, extended_price_cents: 1500 } ]
    )
    complete_pos_sale!(transaction: sale, user: @user, register_session: @session)

    scope = Pos::ReportScope.from_params(store: @store, params: { register_session_id: @session.id })
    report = Pos::OperationalMarginReport.call(scope: scope)

    assert_equal 1500, report.unknown_cost_revenue_cents
    assert_equal 0, report.estimated_margin_cents
    assert_equal 0, report.actual_margin_cents
  end
end
