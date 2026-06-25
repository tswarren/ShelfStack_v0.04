# frozen_string_literal: true

class BackfillPhase851PosDiscounts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    ensure_legacy_reason!
    legacy_reason = DiscountReason.find_by!(reason_key: "legacy_unspecified")

    backfill_line_discounts!(legacy_reason)
    backfill_transaction_discounts!(legacy_reason)
  end

  def down
    PosDiscountAllocation.where("pos_discount_application_id IN (?)",
                                PosDiscountApplication.where(source: "legacy").select(:id)).delete_all
    PosDiscountApplication.where(source: "legacy").delete_all
  end

  private

  def ensure_legacy_reason!
    DiscountReason.find_or_create_by!(reason_key: "legacy_unspecified") do |reason|
      reason.name = "Legacy / Unspecified"
      reason.sort_order = 80
      reason.active = true
    end
  end

  def backfill_line_discounts!(legacy_reason)
    PosTransactionLine.where("line_discount_cents > 0").find_each do |line|
      next if PosDiscountApplication.exists?(pos_transaction_line_id: line.id, source: "legacy", scope: "line")

      application = PosDiscountApplication.create!(
        pos_transaction: line.pos_transaction,
        pos_transaction_line: line,
        discount_reason: legacy_reason,
        scope: "line",
        source: "legacy",
        discount_method: "amount",
        entered_amount_cents: line.line_discount_cents,
        base_amount_cents: line.unit_price_cents * line.quantity.abs,
        calculated_discount_cents: line.line_discount_cents,
        applied_discount_cents: line.line_discount_cents,
        stack_order: 1,
        applied_by_user: line.pos_transaction.cashier_user,
        applied_at: line.pos_transaction.completed_at || line.updated_at
      )

      PosDiscountAllocation.create!(
        pos_discount_application: application,
        pos_transaction: line.pos_transaction,
        pos_transaction_line: line,
        scope: "line",
        allocation_base_cents: line.unit_price_cents * line.quantity.abs,
        allocated_discount_cents: line.line_discount_cents,
        line_number_snapshot: line.line_number
      )
    end
  end

  def backfill_transaction_discounts!(legacy_reason)
    PosTransaction.find_each do |transaction|
      total_transaction_discount = transaction.pos_transaction_lines.sum(:transaction_discount_cents)
      next if total_transaction_discount.zero?
      next if PosDiscountApplication.exists?(pos_transaction_id: transaction.id, source: "legacy", scope: "transaction")

      application = PosDiscountApplication.create!(
        pos_transaction: transaction,
        discount_reason: legacy_reason,
        scope: "transaction",
        source: "legacy",
        discount_method: "amount",
        entered_amount_cents: total_transaction_discount,
        base_amount_cents: total_transaction_discount,
        calculated_discount_cents: total_transaction_discount,
        applied_discount_cents: total_transaction_discount,
        stack_order: 1,
        applied_by_user: transaction.cashier_user,
        applied_at: transaction.completed_at || transaction.updated_at
      )

      transaction.pos_transaction_lines.where("transaction_discount_cents > 0").find_each do |line|
        PosDiscountAllocation.create!(
          pos_discount_application: application,
          pos_transaction: transaction,
          pos_transaction_line: line,
          scope: "transaction",
          allocation_base_cents: line.unit_price_cents * line.quantity.abs,
          allocated_discount_cents: line.transaction_discount_cents,
          line_number_snapshot: line.line_number
        )
      end
    end
  end
end
