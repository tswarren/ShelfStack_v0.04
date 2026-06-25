# frozen_string_literal: true

require "test_helper"

class Pos::DiscountActivityQueryTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @user = create_user!
    @workstation = create_workstation!(store: @store)
    @variant = create_product_variant!
    @reason = DiscountReason.create!(reason_key: "report_test", name: "Report #{SecureRandom.hex(4)}")
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000 } ]
    )
    @line = @transaction.pos_transaction_lines.first
  end

  test "query discounts by reason" do
    Pos::DiscountApplicationService.call!(
      transaction: @transaction,
      scope: "line",
      line: @line,
      discount_reason: @reason,
      discount_method: "amount",
      entered_amount_cents: 100,
      actor: @user
    )

    totals = PosDiscountApplication.active_records
                                   .joins(:discount_reason)
                                   .group("discount_reasons.reason_key")
                                   .sum(:applied_discount_cents)

    assert_equal 100, totals[@reason.reason_key]
  end

  test "allocations preserve department context for reporting" do
    Pos::DiscountApplicationService.call!(
      transaction: @transaction,
      scope: "line",
      line: @line,
      discount_reason: @reason,
      discount_method: "amount",
      entered_amount_cents: 100,
      actor: @user
    )

    allocation = @transaction.reload.pos_discount_allocations.first
    assert_not_nil allocation
    assert_equal 100, allocation.allocated_discount_cents
    assert allocation.product_variant_id.present? || allocation.variant_sku_snapshot.present?
  end
end
