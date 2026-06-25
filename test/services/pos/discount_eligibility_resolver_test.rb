# frozen_string_literal: true

require "test_helper"

class Pos::DiscountEligibilityResolverTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @user = create_user!
    @workstation = create_workstation!(store: @store)
    @sub_department = create_product_variant!.sub_department
    @variant = create_product_variant!(sub_department: @sub_department, sku: "ELIG-1", selling_price_cents: 1000)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000 } ]
    )
    @line = @transaction.pos_transaction_lines.first
  end

  test "normal variant line is discountable" do
    result = Pos::DiscountEligibilityResolver.call(@line)

    assert result.discountable
  end

  test "gift card sale line is not discountable" do
    line = @transaction.pos_transaction_lines.create!(
      line_number: 2,
      line_type: "gift_card_sale",
      quantity: 1,
      unit_price_cents: 2500,
      extended_price_cents: 2500
    )

    result = Pos::DiscountEligibilityResolver.call(line)

    assert_not result.discountable
    assert_equal "gift_card_sale", result.reason_code
  end

  test "return line is not discountable" do
    line = @transaction.pos_transaction_lines.create!(
      line_number: 2,
      line_type: "variant",
      product_variant: @variant,
      product: @variant.product,
      quantity: -1,
      unit_price_cents: 1000,
      extended_price_cents: 1000,
      return_disposition: "return_to_stock"
    )

    result = Pos::DiscountEligibilityResolver.call(line)

    assert_not result.discountable
    assert_equal "return_line", result.reason_code
  end

  test "department non-discountable" do
    @sub_department.department.update!(discountable: false)

    result = Pos::DiscountEligibilityResolver.call(@line)

    assert_not result.discountable
    assert_equal "department_non_discountable", result.reason_code
  end

  test "subdepartment non-discountable" do
    @sub_department.update!(discountable: false)

    result = Pos::DiscountEligibilityResolver.call(@line)

    assert_not result.discountable
    assert_equal "sub_department_non_discountable", result.reason_code
  end

  test "product non-discountable" do
    @variant.product.update!(discountable: false)

    result = Pos::DiscountEligibilityResolver.call(@line)

    assert_not result.discountable
    assert_equal "product_non_discountable", result.reason_code
  end

  test "variant non-discountable" do
    @variant.update!(discountable: false)

    result = Pos::DiscountEligibilityResolver.call(@line)

    assert_not result.discountable
    assert_equal "variant_non_discountable", result.reason_code
  end

  test "open ring line in discountable subdepartment is discountable" do
    line = @transaction.pos_transaction_lines.create!(
      line_number: 2,
      line_type: "open_ring",
      sub_department: @sub_department,
      quantity: 1,
      unit_price_cents: 500,
      extended_price_cents: 500,
      open_ring_description: "Custom item"
    )

    result = Pos::DiscountEligibilityResolver.call(line)

    assert result.discountable
  end

  test "open ring line in non-discountable subdepartment is not discountable" do
    @sub_department.update!(discountable: false)
    line = @transaction.pos_transaction_lines.create!(
      line_number: 2,
      line_type: "open_ring",
      sub_department: @sub_department,
      quantity: 1,
      unit_price_cents: 500,
      extended_price_cents: 500,
      open_ring_description: "Custom item"
    )

    result = Pos::DiscountEligibilityResolver.call(line)

    assert_not result.discountable
    assert_equal "sub_department_non_discountable", result.reason_code
  end

  test "zero remaining amount is not discountable" do
    result = Pos::DiscountEligibilityResolver.call(@line, remaining_discountable_cents: 0)

    assert_not result.discountable
    assert_equal "zero_remaining_amount", result.reason_code
  end
end
