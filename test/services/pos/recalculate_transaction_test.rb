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
      lines: [{ product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 }]
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
      lines: [{
        product_variant: @variant,
        quantity: -1,
        unit_price_cents: 1000,
        extended_price_cents: 1000,
        return_disposition: "return_to_stock"
      }]
    )

    Pos::RecalculateTransaction.call!(transaction)

    assert transaction.total_cents.negative?
    assert_equal transaction.tax_cents, transaction.pos_transaction_lines.sum(&:tax_cents) * -1
    assert_equal "return", transaction.transaction_type
  end
end
