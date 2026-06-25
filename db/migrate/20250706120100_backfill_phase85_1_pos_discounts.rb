# frozen_string_literal: true

class BackfillPhase851PosDiscounts < ActiveRecord::Migration[8.1]
  class LegacyDiscountReason < ApplicationRecord
    self.table_name = "discount_reasons"
  end

  class LegacyPosTransaction < ApplicationRecord
    self.table_name = "pos_transactions"
  end

  class LegacyPosTransactionLine < ApplicationRecord
    self.table_name = "pos_transaction_lines"
  end

  class LegacyPosDiscountApplication < ApplicationRecord
    self.table_name = "pos_discount_applications"
    has_many :pos_discount_allocations,
             class_name: "BackfillPhase851PosDiscounts::LegacyPosDiscountAllocation",
             foreign_key: :pos_discount_application_id
  end

  class LegacyPosDiscountAllocation < ApplicationRecord
    self.table_name = "pos_discount_allocations"
  end

  def up
    legacy_reason = ensure_legacy_reason!

    backfill_line_discounts!(legacy_reason)
    backfill_transaction_discounts!(legacy_reason)
  end

  def down
    LegacyPosDiscountAllocation.where(
      pos_discount_application_id: LegacyPosDiscountApplication.where(source: "legacy").select(:id)
    ).delete_all
    LegacyPosDiscountApplication.where(source: "legacy").delete_all
  end

  private

  def ensure_legacy_reason!
    LegacyDiscountReason.find_or_create_by!(reason_key: "legacy_unspecified") do |reason|
      reason.name = "Legacy / Unspecified"
      reason.sort_order = 80
      reason.active = true
    end
  end

  def backfill_line_discounts!(legacy_reason)
    LegacyPosTransactionLine.where("line_discount_cents > 0").find_each do |line|
      transaction do
        application = LegacyPosDiscountApplication.find_or_create_by!(
          pos_transaction_line_id: line.id,
          source: "legacy",
          scope: "line"
        ) do |record|
          assign_line_application_attributes!(record, line:, legacy_reason:)
        end

        LegacyPosDiscountAllocation.find_or_create_by!(
          pos_discount_application_id: application.id,
          pos_transaction_line_id: line.id,
          scope: "line"
        ) do |allocation|
          assign_line_allocation_attributes!(allocation, application:, line:)
        end
      end
    end
  end

  def backfill_transaction_discounts!(legacy_reason)
    LegacyPosTransaction.find_each do |transaction|
      lines = LegacyPosTransactionLine.where(pos_transaction_id: transaction.id).where("transaction_discount_cents > 0")
      total_transaction_discount = lines.sum(:transaction_discount_cents)
      next if total_transaction_discount.zero?

      transaction do
        application = LegacyPosDiscountApplication.find_or_create_by!(
          pos_transaction_id: transaction.id,
          source: "legacy",
          scope: "transaction"
        ) do |record|
          assign_transaction_application_attributes!(record, transaction:, legacy_reason:, total_transaction_discount:)
        end

        lines.find_each do |line|
          LegacyPosDiscountAllocation.find_or_create_by!(
            pos_discount_application_id: application.id,
            pos_transaction_line_id: line.id,
            scope: "transaction"
          ) do |allocation|
            assign_transaction_allocation_attributes!(allocation, application:, transaction:, line:)
          end
        end
      end
    end
  end

  def assign_line_application_attributes!(application, line:, legacy_reason:)
    transaction = LegacyPosTransaction.find(line.pos_transaction_id)
    application.assign_attributes(
      pos_transaction_id: line.pos_transaction_id,
      discount_reason_id: legacy_reason.id,
      discount_method: "amount",
      entered_amount_cents: line.line_discount_cents,
      base_amount_cents: line.unit_price_cents * line.quantity.abs,
      calculated_discount_cents: line.line_discount_cents,
      applied_discount_cents: line.line_discount_cents,
      stack_order: 1,
      applied_by_user_id: transaction.cashier_user_id,
      applied_at: transaction.completed_at || line.updated_at
    )
  end

  def assign_line_allocation_attributes!(allocation, application:, line:)
    allocation.assign_attributes(
      pos_transaction_id: line.pos_transaction_id,
      allocation_base_cents: line.unit_price_cents * line.quantity.abs,
      allocated_discount_cents: line.line_discount_cents,
      line_number_snapshot: line.line_number
    )
  end

  def assign_transaction_application_attributes!(application, transaction:, legacy_reason:, total_transaction_discount:)
    application.assign_attributes(
      discount_reason_id: legacy_reason.id,
      discount_method: "amount",
      entered_amount_cents: total_transaction_discount,
      base_amount_cents: total_transaction_discount,
      calculated_discount_cents: total_transaction_discount,
      applied_discount_cents: total_transaction_discount,
      stack_order: 2,
      applied_by_user_id: transaction.cashier_user_id,
      applied_at: transaction.completed_at || transaction.updated_at
    )
  end

  def assign_transaction_allocation_attributes!(allocation, application:, transaction:, line:)
    allocation.assign_attributes(
      pos_transaction_id: transaction.id,
      allocation_base_cents: line.unit_price_cents * line.quantity.abs,
      allocated_discount_cents: line.transaction_discount_cents,
      line_number_snapshot: line.line_number
    )
  end
end
