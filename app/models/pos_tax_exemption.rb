# frozen_string_literal: true

class PosTaxExemption < ApplicationRecord
  belongs_to :pos_transaction
  belongs_to :tax_exception_reason
  belongs_to :exempted_by_user, class_name: "User"
  belongs_to :voided_by_user, class_name: "User", optional: true

  validates :exempted_at, presence: true
  validate :reason_allows_exemption
  validate :cannot_change_when_transaction_locked, on: :update

  scope :active_records, -> { where(voided_at: nil) }

  def active?
    voided_at.blank?
  end

  def voided?
    voided_at.present?
  end

  private

  def reason_allows_exemption
    return if tax_exception_reason.blank?

    errors.add(:tax_exception_reason, "must allow exemption") unless tax_exception_reason.allows_exemption?
  end

  def cannot_change_when_transaction_locked
    return if pos_transaction.blank? || pos_transaction.editable?

    errors.add(:base, "cannot modify tax exemptions on a locked transaction")
  end
end
