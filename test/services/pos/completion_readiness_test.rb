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
      lines: [{ product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 }]
    )
    Pos::RecalculateTransaction.call!(@transaction, business_date: @session.business_date)
  end

  test "ready when register open lines present and tenders match" do
    @transaction.pos_tenders.create!(tender_type: "cash", amount_cents: @transaction.total_cents)

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
      tender_inputs: [{ tender_type: "cash", amount_dollars: format("%.2f", @transaction.total_cents / 100.0) }]
    )

    assert result.ready?
  end

  test "blocked when tender total is short" do
    result = Pos::CompletionReadiness.check(
      transaction: @transaction,
      register_session: @session,
      tender_inputs: [{ tender_type: "cash", amount_dollars: "1.00" }]
    )

    assert result.blocked?
    assert result.blockers.any? { |check| check.key == :tenders }
  end
end
