# frozen_string_literal: true

require "test_helper"

class Pos::CompletionReadinessTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(selling_price_cents: 1000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 3)
    @session = open_register_session!(store: @store, workstation: @workstation, user: @user, opening_cash_cents: 5000)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 } ]
    )
    Pos::RecalculateTransaction.call!(@transaction, business_date: @session.business_date)
  end

  test "ready when register open lines present and tenders match" do
    create_pos_tender!(@transaction, tender_type: "cash", amount_cents: @transaction.total_cents)

    result = Pos::CompletionReadiness.check(
      transaction: @transaction.reload,
      register_session: @session
    )

    assert result.ready?
    assert result.checks.any? { |check| check.key == :tenders && check.status == :ok }
  end

  test "blocked without register session" do
    result = Pos::CompletionReadiness.check(
      transaction: @transaction,
      register_session: nil
    )

    assert result.blocked?
    assert_includes result.blockers.map(&:key), :register_session
  end

  test "blocked without lines" do
    empty = create_pos_transaction!(store: @store, workstation: @workstation, user: @user, lines: [])

    result = Pos::CompletionReadiness.check(
      transaction: empty,
      register_session: @session
    )

    assert result.blocked?
    assert_includes result.blockers.map(&:key), :lines
  end

  test "evaluates proposed tender inputs" do
    result = Pos::CompletionReadiness.check(
      transaction: @transaction,
      register_session: @session,
      tender_inputs: [ { tender_type: "cash", amount_dollars: format("%.2f", @transaction.total_cents / 100.0) } ]
    )

    assert result.ready?
  end

  test "blocked when tender total is short" do
    partial = format("%.2f", @transaction.total_cents / 200.0)

    result = Pos::CompletionReadiness.check(
      transaction: @transaction,
      register_session: @session,
      tender_inputs: [ { tender_type: "cash", amount_dollars: partial } ]
    )

    assert result.blocked?
    tender_blocker = result.blockers.find { |check| check.key == :tenders }
    assert tender_blocker.message.include?("short")
    assert result.alert_blockers.any? { |check| check.key == :tenders }
  end

  test "pending tender entry is blocked but not shown as readiness alert" do
    result = Pos::CompletionReadiness.check(
      transaction: @transaction,
      register_session: @session
    )

    assert result.blocked?
    refute result.tender_ready?
    assert result.blockers.any? { |check| check.key == :tenders && check.message == Pos::CompletionReadiness::TENDER_AMOUNTS_PENDING_MESSAGE }
    assert result.alert_blockers.none? { |check| check.key == :tenders }
  end

  test "structural blocked without register but tender not structural" do
    result = Pos::CompletionReadiness.check(
      transaction: @transaction,
      register_session: nil,
      tender_inputs: [ { tender_type: "cash", amount_dollars: "1.00" } ]
    )

    assert result.structural_blocked?
    refute result.tender_ready?
    refute result.complete_ready?
  end

  test "complete ready with matching tender inputs and open register" do
    result = Pos::CompletionReadiness.check(
      transaction: @transaction,
      register_session: @session,
      tender_inputs: [ { tender_type: "cash", amount_dollars: format("%.2f", @transaction.total_cents / 100.0) } ]
    )

    assert result.tender_ready?
    assert result.complete_ready?
  end

  test "normalizes positive refund tender inputs" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: -1, unit_price_cents: 1000, extended_price_cents: -1000 } ]
    )
    Pos::RecalculateTransaction.call!(return_txn, business_date: @session.business_date)
    total = return_txn.total_cents.abs

    result = Pos::CompletionReadiness.check(
      transaction: return_txn,
      register_session: @session,
      tender_inputs: [ { tender_type: "cash", amount_dollars: format("%.2f", total / 100.0) } ]
    )

    assert result.tender_ready?
  end

  test "accepts cash refund submitted via sale-mode tendered_dollars field" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: -1, unit_price_cents: 1000, extended_price_cents: -1000 } ]
    )
    Pos::RecalculateTransaction.call!(return_txn, business_date: @session.business_date)
    total = return_txn.total_cents.abs

    result = Pos::CompletionReadiness.check(
      transaction: return_txn,
      register_session: @session,
      tender_inputs: [ { tender_type: "cash", tendered_dollars: format("%.2f", total / 100.0) } ]
    )

    assert result.tender_ready?
  end

  test "ready for even exchange without tender rows when total is zero" do
    exchange = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 },
        { product_variant: @variant, quantity: -1, unit_price_cents: 1000, extended_price_cents: -1000 }
      ]
    )
    Pos::RecalculateTransaction.call!(exchange, business_date: @session.business_date)

    result = Pos::CompletionReadiness.check(
      transaction: exchange,
      register_session: @session
    )

    assert exchange.total_cents.zero?
    assert result.tender_ready?
  end

  test "sale over cash refund threshold does not require cash refund authorization" do
    expensive = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 6000, extended_price_cents: 6000 } ]
    )
    Pos::RecalculateTransaction.call!(expensive, business_date: @session.business_date)

    result = Pos::CompletionReadiness.check(
      transaction: expensive,
      register_session: @session,
      tender_inputs: [ { tender_type: "cash", amount_dollars: format("%.2f", expensive.total_cents / 100.0) } ]
    )

    refute result.blockers.any? { |check| check.key == :cash_refund_auth }
    assert result.complete_ready?
  end

  test "return cash refund over threshold requires authorization" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: -1, unit_price_cents: 6000, extended_price_cents: -6000 } ]
    )
    Pos::RecalculateTransaction.call!(return_txn, business_date: @session.business_date)
    total = return_txn.total_cents.abs

    result = Pos::CompletionReadiness.check(
      transaction: return_txn,
      register_session: @session,
      tender_inputs: [ { tender_type: "cash", amount_dollars: format("%.2f", total / 100.0) } ]
    )

    assert result.structural_blocked?
    assert result.blockers.any? { |check| check.key == :cash_refund_auth }
  end

  test "evaluates multi-row settlement preview totals" do
    card_amount = @transaction.total_cents / 3
    cash_tendered = @transaction.total_cents - (card_amount * 2)

    result = Pos::CompletionReadiness.check(
      transaction: @transaction,
      register_session: @session,
      tender_inputs: [
        { tender_type: "card", amount_cents: card_amount, card_brand: "visa" },
        { tender_type: "card", amount_cents: card_amount, card_brand: "mastercard" },
        { tender_type: "cash", tendered_cents: cash_tendered }
      ]
    )

    assert result.tender_ready?
    assert result.complete_ready?
  end

  test "evaluates split refund preview totals" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: -1, unit_price_cents: 1000, extended_price_cents: -1000 } ]
    )
    Pos::RecalculateTransaction.call!(return_txn, business_date: @session.business_date)
    half = return_txn.total_cents.abs / 2
    remaining = return_txn.total_cents - (-half)

    result = Pos::CompletionReadiness.check(
      transaction: return_txn,
      register_session: @session,
      tender_inputs: [
        { tender_type: "card", amount_cents: -half, card_brand: "visa" },
        { tender_type: "cash", amount_cents: remaining }
      ]
    )

    assert result.tender_ready?
  end

  test "evaluates explicit zero cash tender input on even exchange" do
    exchange = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 },
        { product_variant: @variant, quantity: -1, unit_price_cents: 1000, extended_price_cents: -1000 }
      ]
    )
    Pos::RecalculateTransaction.call!(exchange, business_date: @session.business_date)

    result = Pos::CompletionReadiness.check(
      transaction: exchange,
      register_session: @session,
      tender_inputs: [ { tender_type: "cash", amount_dollars: "0.00" } ]
    )

    assert result.tender_ready?
  end
end
