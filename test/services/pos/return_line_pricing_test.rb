# frozen_string_literal: true

require "test_helper"

class Pos::ReturnLinePricingTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(selling_price_cents: 1000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
  end

  test "receipted return uses net sold price after line and order discounts" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        line_discount_cents: 100,
        extended_price_cents: 900
      }],
      attrs: { discount_cents: 100 }
    )
    Pos::RecalculateTransaction.call!(sale)
    complete_pos_sale!(transaction: sale, user: @user, register_session: @register_session)
    source_line = sale.pos_transaction_lines.first

    assert_operator source_line.extended_price_cents, :<, source_line.unit_price_cents

    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{
        product_variant: @variant,
        quantity: -1,
        unit_price_cents: 0,
        extended_price_cents: 0,
        return_disposition: "return_to_stock",
        source_transaction_line: source_line
      }]
    )

    Pos::RecalculateTransaction.call!(return_txn)
    return_line = return_txn.pos_transaction_lines.first

    assert_equal source_line.extended_price_cents, return_line.extended_price_cents.abs
    assert_equal source_line.tax_cents, return_line.tax_cents.abs
    assert return_txn.total_cents.negative?
  end

  test "partial return pro-rates discounted source line" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{
        product_variant: @variant,
        quantity: 2,
        unit_price_cents: 1000,
        line_discount_cents: 0,
        extended_price_cents: 2000
      }],
      attrs: { discount_cents: 400 }
    )
    Pos::RecalculateTransaction.call!(sale)
    complete_pos_sale!(transaction: sale, user: @user, register_session: @register_session)
    source_line = sale.pos_transaction_lines.first
    assert_equal 1600, source_line.extended_price_cents

    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{
        product_variant: @variant,
        quantity: -1,
        unit_price_cents: 0,
        extended_price_cents: 0,
        return_disposition: "return_to_stock",
        source_transaction_line: source_line
      }]
    )

    Pos::RecalculateTransaction.call!(return_txn)
    return_line = return_txn.pos_transaction_lines.first

    assert_equal 800, return_line.extended_price_cents.abs
    assert_equal 800, Pos::ReturnLinePricing.effective_unit_extended_cents(source_line)
  end
end
