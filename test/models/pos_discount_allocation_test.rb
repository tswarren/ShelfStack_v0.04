# frozen_string_literal: true

require "test_helper"

class PosDiscountAllocationTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @user = create_user!
    @workstation = create_workstation!(store: @store)
    @variant = create_product_variant!
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000 } ]
    )
    @line = @transaction.pos_transaction_lines.first
    @reason = DiscountReason.create!(reason_key: "alloc_test", name: "Alloc Test #{SecureRandom.hex(4)}")
    @application = PosDiscountApplication.create!(
      pos_transaction: @transaction,
      pos_transaction_line: @line,
      discount_reason: @reason,
      scope: "line",
      source: "manual",
      discount_method: "amount",
      entered_amount_cents: 100,
      base_amount_cents: 1000,
      calculated_discount_cents: 100,
      applied_discount_cents: 100,
      stack_order: 1,
      applied_by_user: @user,
      applied_at: Time.current
    )
  end

  test "requires nonnegative allocated amounts" do
    allocation = PosDiscountAllocation.new(
      pos_discount_application: @application,
      pos_transaction: @transaction,
      pos_transaction_line: @line,
      scope: "line",
      allocation_base_cents: 1000,
      allocated_discount_cents: -1
    )

    assert_not allocation.valid?
    assert_includes allocation.errors[:allocated_discount_cents], "must be greater than or equal to 0"
  end

  test "allocation line must belong to same transaction" do
    other_transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 500 } ]
    )
    other_line = other_transaction.pos_transaction_lines.first

    allocation = PosDiscountAllocation.new(
      pos_discount_application: @application,
      pos_transaction: @transaction,
      pos_transaction_line: other_line,
      scope: "line",
      allocation_base_cents: 1000,
      allocated_discount_cents: 100
    )

    assert_not allocation.valid?
    assert_includes allocation.errors[:pos_transaction_line], "must belong to the same transaction"
  end

  test "allocation transaction must match application transaction" do
    other_transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 500 } ]
    )

    allocation = PosDiscountAllocation.new(
      pos_discount_application: @application,
      pos_transaction: other_transaction,
      pos_transaction_line: @line,
      scope: "line",
      allocation_base_cents: 1000,
      allocated_discount_cents: 100
    )

    assert_not allocation.valid?
    assert_includes allocation.errors[:pos_transaction], "must match the discount application transaction"
  end
end
