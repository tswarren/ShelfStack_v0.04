# frozen_string_literal: true

require "test_helper"

class PosDiscountApplicationTest < ActiveSupport::TestCase
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
    @reason = DiscountReason.create!(reason_key: "test_reason", name: "Test Reason #{SecureRandom.hex(4)}")
  end

  test "requires transaction and discount reason" do
    application = PosDiscountApplication.new(
      scope: "line",
      source: "manual",
      discount_method: "amount",
      entered_amount_cents: 100,
      stack_order: 1,
      applied_by_user: @user,
      applied_at: Time.current
    )

    assert_not application.valid?
    assert_includes application.errors[:pos_transaction], "must exist"
    assert_includes application.errors[:discount_reason], "must exist"
  end

  test "line scope requires line" do
    application = build_application(scope: "line", line: nil)

    assert_not application.valid?
    assert_includes application.errors[:pos_transaction_line], "must be present for line-scope discounts"
  end

  test "line must belong to same transaction" do
    other_transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000 } ]
    )
    application = build_application
    application.pos_transaction = other_transaction

    assert_not application.valid?
    assert_includes application.errors[:pos_transaction_line], "must belong to the same transaction"
  end

  test "transaction scope must not have line" do
    application = build_application(scope: "transaction", line: @line)

    assert_not application.valid?
    assert_includes application.errors[:pos_transaction_line], "must be blank for transaction-scope discounts"
  end

  test "amount method requires entered_amount_cents" do
    application = build_application(discount_method: "amount", entered_amount_cents: nil)

    assert_not application.valid?
    assert_includes application.errors[:entered_amount_cents], "must be present for amount discounts"
  end

  test "percent method requires entered_percent_bps" do
    application = build_application(
      discount_method: "percent",
      entered_amount_cents: nil,
      entered_percent_bps: nil
    )

    assert_not application.valid?
    assert_includes application.errors[:entered_percent_bps], "must be present for percent discounts"
  end

  test "cannot change when transaction is completed" do
    application = build_application
    application.save!

    @transaction.update!(status: "completed", transaction_number: "001-001-000001", completed_at: Time.current)

    assert_not application.update(note: "changed")
    assert_includes application.errors[:base], "cannot modify discount applications on a locked transaction"
  end

  test "active_records excludes voided applications" do
    application = build_application
    application.save!
    application.update!(voided_at: Time.current, voided_by_user: @user)

    assert_not_includes PosDiscountApplication.active_records, application
  end

  private

  def build_application(scope: "line", line: @line, discount_method: "amount", entered_amount_cents: 100, entered_percent_bps: nil)
    PosDiscountApplication.new(
      pos_transaction: @transaction,
      pos_transaction_line: line,
      discount_reason: @reason,
      scope: scope,
      source: "manual",
      discount_method: discount_method,
      entered_amount_cents: entered_amount_cents,
      entered_percent_bps: entered_percent_bps,
      base_amount_cents: 1000,
      calculated_discount_cents: entered_amount_cents || 0,
      applied_discount_cents: entered_amount_cents || 0,
      stack_order: 1,
      applied_by_user: @user,
      applied_at: Time.current
    )
  end
end
