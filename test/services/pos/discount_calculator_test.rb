# frozen_string_literal: true

require "test_helper"

class Pos::DiscountCalculatorTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @user = create_user!
    @sub_department = create_product_variant!.sub_department
    @variant_one = create_product_variant!(sub_department: @sub_department, sku: "DISC-1", selling_price_cents: 1000)
    @variant_two = create_product_variant!(sub_department: @sub_department, sku: "DISC-2", selling_price_cents: 2000)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: create_workstation!(store: @store),
      user: @user,
      attrs: { discount_cents: 300 },
      lines: [
        { product_variant: @variant_one, quantity: 1, unit_price_cents: 1000, line_discount_cents: 0, extended_price_cents: 1000 },
        { product_variant: @variant_two, quantity: 1, unit_price_cents: 2000, line_discount_cents: 0, extended_price_cents: 2000 }
      ]
    )
  end

  test "persists transaction discount shares on each line" do
    Pos::DiscountCalculator.apply_transaction_discount!(@transaction.reload)

    lines = @transaction.pos_transaction_lines.order(:line_number)
    assert_equal [100, 200], lines.map(&:transaction_discount_cents)
    assert_equal 300, lines.sum(&:transaction_discount_cents)
    assert_equal [900, 1800], lines.map(&:extended_price_cents)
  end

  test "resets transaction discount shares when order discount is zero" do
    Pos::DiscountCalculator.apply_transaction_discount!(@transaction.reload)
    @transaction.update!(discount_cents: 0)

    Pos::DiscountCalculator.apply_transaction_discount!(@transaction.reload)

    lines = @transaction.pos_transaction_lines.order(:line_number)
    assert lines.all? { |line| line.transaction_discount_cents.zero? }
  end
end
