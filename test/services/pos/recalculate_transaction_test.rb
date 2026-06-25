# frozen_string_literal: true

require "test_helper"

class Pos::RecalculateTransactionTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(selling_price_cents: 1000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
  end

  test "sale transaction total is positive" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 } ]
    )

    Pos::RecalculateTransaction.call!(transaction)

    assert transaction.total_cents.positive?
    assert_equal "sale", transaction.transaction_type
  end

  test "return transaction total is negative" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ {
        product_variant: @variant,
        quantity: -1,
        unit_price_cents: 1000,
        extended_price_cents: 1000,
        return_disposition: "return_to_stock"
      } ]
    )

    Pos::RecalculateTransaction.call!(transaction)

    assert transaction.total_cents.negative?
    assert_equal transaction.tax_cents, transaction.pos_transaction_lines.sum(&:tax_cents) * -1
    assert_equal "return", transaction.transaction_type
  end

  test "line discount is clamped to line gross base" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ {
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        line_discount_cents: 1500,
        extended_price_cents: 1000
      } ]
    )

    Pos::RecalculateTransaction.call!(transaction)
    line = transaction.pos_transaction_lines.first

    assert_equal 1000, line.line_discount_cents
    assert_equal 0, line.extended_price_cents
  end

  test "structured line discount recalculates tax and total from discounted extended price" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 } ]
    )
    reason = DiscountReason.create!(reason_key: "recalc_structured", name: "Recalc structured")
    line = transaction.pos_transaction_lines.first
    PosDiscountApplication.create!(
      pos_transaction: transaction,
      pos_transaction_line: line,
      discount_reason: reason,
      scope: "line",
      source: "manual",
      discount_method: "amount",
      entered_amount_cents: 100,
      stack_order: 1,
      applied_by_user: @user,
      applied_at: Time.current
    )

    Pos::RecalculateTransaction.call!(transaction.reload)
    line.reload

    assert_equal 100, line.line_discount_cents
    assert_equal 900, line.extended_price_cents
    assert_operator line.tax_cents, :<, 60
    assert_equal line.extended_price_cents + line.tax_cents, transaction.total_cents
  end

  test "structured discount on sale line preserves sourced return pricing in exchange" do
    register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ {
        product_variant: @variant,
        quantity: 2,
        unit_price_cents: 1000,
        line_discount_cents: 0,
        extended_price_cents: 2000
      } ],
      attrs: { discount_cents: 400 }
    )
    Pos::RecalculateTransaction.call!(sale)
    complete_pos_sale!(transaction: sale, user: @user, register_session: register_session)
    source_line = sale.pos_transaction_lines.first

    sale_variant = create_product_variant!(
      sub_department: @variant.sub_department,
      sku: "EXCH-NEW-#{SecureRandom.hex(3)}",
      selling_price_cents: 2000
    )

    exchange = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        {
          product_variant: @variant,
          quantity: -1,
          unit_price_cents: 0,
          extended_price_cents: 0,
          return_disposition: "return_to_stock",
          source_transaction_line: source_line
        },
        {
          product_variant: sale_variant,
          quantity: 1,
          unit_price_cents: 2000,
          extended_price_cents: 2000
        }
      ]
    )
    Pos::RecalculateTransaction.call!(exchange)
    return_line = exchange.pos_transaction_lines.find(&:return_line?)
    expected_extended = return_line.extended_price_cents
    expected_line_discount = return_line.line_discount_cents
    expected_tax = return_line.tax_cents

    sale_line = exchange.pos_transaction_lines.find { |line| line.quantity.positive? }
    reason = DiscountReason.create!(reason_key: "exchange_structured", name: "Exchange structured")
    PosDiscountApplication.create!(
      pos_transaction: exchange,
      pos_transaction_line: sale_line,
      discount_reason: reason,
      scope: "line",
      source: "manual",
      discount_method: "amount",
      entered_amount_cents: 200,
      stack_order: 1,
      applied_by_user: @user,
      applied_at: Time.current
    )

    Pos::RecalculateTransaction.call!(exchange.reload)
    return_line.reload

    assert_equal expected_extended, return_line.extended_price_cents
    assert_equal expected_line_discount, return_line.line_discount_cents
    assert_equal expected_tax, return_line.tax_cents
    assert_equal 200, sale_line.reload.line_discount_cents
  end
end
