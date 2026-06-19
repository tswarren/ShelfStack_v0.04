# frozen_string_literal: true

require "test_helper"

class Pos::DiscountInputTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(selling_price_cents: 2000)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: create_workstation!(store: @store),
      user: @user,
      lines: [
        { product_variant: @variant, quantity: 1, unit_price_cents: 2000, line_discount_cents: 0, extended_price_cents: 2000 },
        { product_variant: @variant, quantity: 2, unit_price_cents: 1000, line_discount_cents: 200, extended_price_cents: 1800 }
      ]
    )
  end

  test "resolves flat dollar amount" do
    cents = Pos::DiscountInput.resolve_cents(value: "12.50", input_type: "amount", base_cents: 5000)

    assert_equal 1250, cents
  end

  test "resolves percent of base" do
    cents = Pos::DiscountInput.resolve_cents(value: "10", input_type: "percent", base_cents: 3800)

    assert_equal 380, cents
  end

  test "blank value resolves to zero" do
    assert_equal 0, Pos::DiscountInput.resolve_cents(value: "", input_type: "amount", base_cents: 1000)
  end

  test "rejects invalid percent" do
    assert_raises(Pos::DiscountInput::Error) do
      Pos::DiscountInput.resolve_cents(value: "101", input_type: "percent", base_cents: 1000)
    end
  end

  test "transaction base excludes return lines and line discounts" do
    @transaction.pos_transaction_lines.create!(
      line_number: 3,
      line_type: "variant",
      product_variant: @variant,
      product: @variant.product,
      quantity: -1,
      unit_price_cents: 1000,
      line_discount_cents: 0,
      extended_price_cents: 1000,
      return_disposition: "return_to_stock"
    )

    base = Pos::DiscountInput.discountable_transaction_base_cents(@transaction.reload)

    assert_equal 3800, base
  end

  test "ten percent transaction discount on mixed lines" do
    base = Pos::DiscountInput.discountable_transaction_base_cents(@transaction)
    discount_cents = Pos::DiscountInput.resolve_cents(value: "10", input_type: "percent", base_cents: base)

    @transaction.update!(discount_cents: discount_cents)
    Pos::DiscountCalculator.apply_transaction_discount!(@transaction.reload)

    sale_lines = @transaction.pos_transaction_lines.reject(&:return_line?).sort_by(&:line_number)
    assert_equal discount_cents, sale_lines.sum(&:transaction_discount_cents)
    assert_equal 380, discount_cents
  end
end
