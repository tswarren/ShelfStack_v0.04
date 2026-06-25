# frozen_string_literal: true

require "test_helper"

class Pos::DiscountRecalculatorTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @user = create_user!
    @workstation = create_workstation!(store: @store)
    @sub_department = create_product_variant!.sub_department
    @variant_one = create_product_variant!(sub_department: @sub_department, sku: "REC-1", selling_price_cents: 1000)
    @variant_two = create_product_variant!(sub_department: @sub_department, sku: "REC-2", selling_price_cents: 2000)
    @reason = DiscountReason.create!(reason_key: "recalc_test", name: "Recalc #{SecureRandom.hex(4)}")
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        { product_variant: @variant_one, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 },
        { product_variant: @variant_two, quantity: 1, unit_price_cents: 2000, extended_price_cents: 2000 }
      ]
    )
  end

  test "one line amount discount updates line discount cache" do
    create_application!(scope: "line", line: line(1), method: "amount", entered_amount_cents: 100)

    Pos::DiscountRecalculator.call!(@transaction.reload)

    assert_equal 100, line(1).line_discount_cents
    assert_equal 900, line(1).extended_price_cents
    assert_equal 1, @transaction.pos_discount_allocations.count
  end

  test "one line percent discount updates line discount cache" do
    create_application!(scope: "line", line: line(1), method: "percent", entered_percent_bps: 1000)

    Pos::DiscountRecalculator.call!(@transaction.reload)

    assert_equal 100, line(1).line_discount_cents
    assert_equal 900, line(1).extended_price_cents
  end

  test "two stacked line discounts apply to remaining amount" do
    create_application!(scope: "line", line: line(1), method: "percent", entered_percent_bps: 1000, stack_order: 1)
    create_application!(scope: "line", line: line(1), method: "amount", entered_amount_cents: 50, stack_order: 2)

    Pos::DiscountRecalculator.call!(@transaction.reload)

    assert_equal 150, line(1).line_discount_cents
    assert_equal 850, line(1).extended_price_cents
  end

  test "transaction amount discount allocates across eligible lines" do
    create_application!(scope: "transaction", method: "amount", entered_amount_cents: 300)

    Pos::DiscountRecalculator.call!(@transaction.reload)

    assert_equal [ 100, 200 ], @transaction.pos_transaction_lines.order(:line_number).map(&:transaction_discount_cents)
    assert_equal 300, @transaction.discount_cents
  end

  test "transaction percent discount allocates across eligible subtotal" do
    create_application!(scope: "transaction", method: "percent", entered_percent_bps: 1000)

    Pos::DiscountRecalculator.call!(@transaction.reload)

    assert_equal 300, @transaction.pos_transaction_lines.sum(&:transaction_discount_cents)
    assert_equal 2700, @transaction.pos_transaction_lines.sum(&:extended_price_cents)
  end

  test "transaction discount excludes gift card line" do
    @transaction.pos_transaction_lines.create!(
      line_number: 3,
      line_type: "gift_card_sale",
      quantity: 1,
      unit_price_cents: 5000,
      extended_price_cents: 5000
    )
    create_application!(scope: "transaction", method: "amount", entered_amount_cents: 300)

    Pos::DiscountRecalculator.call!(@transaction.reload)

    gift_card = @transaction.pos_transaction_lines.find_by(line_type: "gift_card_sale")
    assert_equal 0, gift_card.transaction_discount_cents
    assert_equal 5000, gift_card.extended_price_cents
  end

  test "transaction discount excludes non-discountable line" do
    @variant_two.update!(discountable: false)
    create_application!(scope: "transaction", method: "amount", entered_amount_cents: 200)

    Pos::DiscountRecalculator.call!(@transaction.reload)

    assert_equal 0, line(2).transaction_discount_cents
    assert_equal 200, line(1).transaction_discount_cents
  end

  test "caps discount at eligible subtotal" do
    create_application!(scope: "transaction", method: "amount", entered_amount_cents: 5000)

    Pos::DiscountRecalculator.call!(@transaction.reload)

    assert_equal 3000, @transaction.pos_transaction_lines.sum(&:transaction_discount_cents)
    assert @transaction.pos_transaction_lines.all? { |line| line.extended_price_cents >= 0 }
  end

  test "voiding one discount in stack recalculates remaining allocations" do
    first = create_application!(scope: "line", line: line(1), method: "amount", entered_amount_cents: 100, stack_order: 1)
    create_application!(scope: "line", line: line(1), method: "amount", entered_amount_cents: 50, stack_order: 2)

    Pos::DiscountRecalculator.call!(@transaction.reload)
    first.update!(voided_at: Time.current, voided_by_user: @user)

    Pos::DiscountRecalculator.call!(@transaction.reload)

    assert_equal 50, line(1).line_discount_cents
    assert_equal 1, @transaction.pos_discount_allocations.count
  end

  test "line discounts then transaction discount apply to remaining amounts" do
    @transaction.pos_transaction_lines.find_by!(line_number: 2).destroy!
    target = line(1)
    target.update!(unit_price_cents: 2000, extended_price_cents: 2000)
    create_application!(scope: "line", line: target, method: "percent", entered_percent_bps: 1000, stack_order: 1)
    create_application!(scope: "line", line: target, method: "amount", entered_amount_cents: 300, stack_order: 2)
    create_application!(scope: "transaction", method: "percent", entered_percent_bps: 2000, stack_order: 3)

    Pos::DiscountRecalculator.call!(@transaction.reload)

    assert_equal 500, target.reload.line_discount_cents
    assert_equal 300, target.transaction_discount_cents
    assert_equal 1200, target.extended_price_cents
    assert_equal 300, @transaction.discount_cents
  end

  test "transaction discount then line discount respects stack order" do
    create_application!(scope: "transaction", method: "amount", entered_amount_cents: 300, stack_order: 1)
    create_application!(scope: "line", line: line(1), method: "percent", entered_percent_bps: 1000, stack_order: 2)

    Pos::DiscountRecalculator.call!(@transaction.reload)

    assert_equal [ 100, 200 ], @transaction.pos_transaction_lines.order(:line_number).map(&:transaction_discount_cents)
    assert_equal 90, line(1).line_discount_cents
    assert_equal 810, line(1).extended_price_cents
    assert_equal 1800, line(2).extended_price_cents
  end

  test "line discount on one line shrinks transaction discount base" do
    create_application!(scope: "line", line: line(1), method: "amount", entered_amount_cents: 100, stack_order: 1)
    create_application!(scope: "transaction", method: "amount", entered_amount_cents: 290, stack_order: 2)

    Pos::DiscountRecalculator.call!(@transaction.reload)

    assert_equal 100, line(1).line_discount_cents
    assert_equal 90, line(1).transaction_discount_cents
    assert_equal 200, line(2).transaction_discount_cents
    assert_equal 290, @transaction.discount_cents
    assert_equal 2610, @transaction.pos_transaction_lines.sum(&:extended_price_cents)
  end

  test "mixed discounts preserve gross subtotal and total discount math" do
    create_application!(scope: "line", line: line(1), method: "amount", entered_amount_cents: 100, stack_order: 1)
    create_application!(scope: "transaction", method: "amount", entered_amount_cents: 300, stack_order: 2)

    Pos::DiscountRecalculator.call!(@transaction.reload)

    gross = @transaction.pos_transaction_lines.sum { |line| line.unit_price_cents * line.quantity.abs }
    savings = @transaction.pos_transaction_lines.sum(&:line_discount_cents) + @transaction.discount_cents

    assert_equal 3000, gross
    assert_equal 400, savings
    assert_equal gross - savings, @transaction.pos_transaction_lines.sum(&:extended_price_cents)
  end

  test "line discount is not allocated when variant becomes non-discountable" do
    application = create_application!(scope: "line", line: line(1), method: "amount", entered_amount_cents: 100)

    Pos::DiscountRecalculator.call!(@transaction.reload)

    assert_equal 100, line(1).line_discount_cents
    assert_equal 100, application.reload.applied_discount_cents

    @variant_one.update!(discountable: false)
    Pos::DiscountRecalculator.call!(@transaction.reload)

    assert_equal 0, line(1).reload.line_discount_cents
    assert_equal 0, application.reload.applied_discount_cents
    assert_equal 0, @transaction.pos_discount_allocations.count
  end

  test "transaction discount allocation never creates negative rounding remainder" do
    @transaction.pos_transaction_lines.destroy_all
    4.times do |index|
      variant = create_product_variant!(sub_department: @sub_department, sku: "PENNY-#{index}", selling_price_cents: 1)
      @transaction.pos_transaction_lines.create!(
        line_number: index + 1,
        line_type: "variant",
        product_variant: variant,
        product: variant.product,
        quantity: 1,
        unit_price_cents: 1,
        extended_price_cents: 1
      )
    end
    create_application!(scope: "transaction", method: "amount", entered_amount_cents: 2)

    assert_nothing_raised do
      Pos::DiscountRecalculator.call!(@transaction.reload)
    end

    shares = @transaction.pos_transaction_lines.order(:line_number).map(&:transaction_discount_cents)
    assert_equal [ 1, 1, 0, 0 ], shares
    assert_equal 2, shares.sum
    assert @transaction.pos_discount_allocations.all? { |allocation| allocation.allocated_discount_cents.positive? }
  end

  private

  def line(number)
    @transaction.pos_transaction_lines.find_by!(line_number: number)
  end

  def create_application!(scope:, method:, line: nil, entered_amount_cents: nil, entered_percent_bps: nil, stack_order: 1,
                        transaction: @transaction)
    PosDiscountApplication.create!(
      pos_transaction: transaction,
      pos_transaction_line: line,
      discount_reason: @reason,
      scope: scope,
      source: "manual",
      discount_method: method,
      entered_amount_cents: entered_amount_cents,
      entered_percent_bps: entered_percent_bps,
      stack_order: stack_order,
      applied_by_user: @user,
      applied_at: Time.current
    )
  end
end
