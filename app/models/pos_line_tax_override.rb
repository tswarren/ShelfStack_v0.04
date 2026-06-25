# frozen_string_literal: true

class PosLineTaxOverride < ApplicationRecord
  belongs_to :pos_transaction
  belongs_to :pos_transaction_line
  belongs_to :tax_exception_reason
  belongs_to :override_tax_category, class_name: "TaxCategory"
  belongs_to :override_store_tax_rate, class_name: "StoreTaxRate"
  belongs_to :overridden_by_user, class_name: "User"
  belongs_to :voided_by_user, class_name: "User", optional: true

  validates :override_tax_rate_bps, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :overridden_at, presence: true
  validate :reason_allows_rate_override
  validate :line_belongs_to_transaction
  validate :cannot_change_when_transaction_locked, on: :update

  scope :active_records, -> { where(voided_at: nil) }

  def active?
    voided_at.blank?
  end

  def voided?
    voided_at.present?
  end

  private

  def reason_allows_rate_override
    return if tax_exception_reason.blank?

    errors.add(:tax_exception_reason, "must allow rate override") unless tax_exception_reason.allows_rate_override?
  end

  def line_belongs_to_transaction
    return if pos_transaction_line.blank? || pos_transaction_id.blank?
    return if pos_transaction_line.pos_transaction_id == pos_transaction_id

    errors.add(:pos_transaction_line, "must belong to the same transaction")
  end

  def cannot_change_when_transaction_locked
    return if pos_transaction.blank? || pos_transaction.editable?

    errors.add(:base, "cannot modify line tax overrides on a locked transaction")
  end
end
