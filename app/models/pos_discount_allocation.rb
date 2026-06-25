# frozen_string_literal: true

class PosDiscountAllocation < ApplicationRecord
  SCOPES = PosDiscountApplication::SCOPES

  belongs_to :pos_discount_application
  belongs_to :pos_transaction
  belongs_to :pos_transaction_line
  belongs_to :product_variant, optional: true
  belongs_to :product, optional: true
  belongs_to :sub_department, optional: true
  belongs_to :department, optional: true
  belongs_to :tax_category, optional: true

  validates :scope, presence: true, inclusion: { in: SCOPES }
  validates :allocation_base_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :allocated_discount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :same_transaction_as_application
  validate :line_belongs_to_transaction

  private

  def same_transaction_as_application
    return if pos_discount_application.blank? || pos_transaction_id.blank?
    return if pos_discount_application.pos_transaction_id == pos_transaction_id

    errors.add(:pos_transaction, "must match the discount application transaction")
  end

  def line_belongs_to_transaction
    return if pos_transaction_line.blank? || pos_transaction_id.blank?
    return if pos_transaction_line.pos_transaction_id == pos_transaction_id

    errors.add(:pos_transaction_line, "must belong to the same transaction")
  end
end
