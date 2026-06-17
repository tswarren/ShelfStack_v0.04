# frozen_string_literal: true

class ReceivingDiscrepancy < ApplicationRecord
  DISCREPANCY_TYPES = %w[short over other].freeze

  belongs_to :receipt_line

  validates :discrepancy_type, presence: true, inclusion: { in: DISCREPANCY_TYPES }
  validates :quantity_delta, presence: true, numericality: { only_integer: true }
  validate :quantity_delta_must_be_nonzero

  private

  def quantity_delta_must_be_nonzero
    return if quantity_delta.blank? || quantity_delta.nonzero?

    errors.add(:quantity_delta, "must be non-zero")
  end
end
