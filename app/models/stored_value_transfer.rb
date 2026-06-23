# frozen_string_literal: true

class StoredValueTransfer < ApplicationRecord
  belongs_to :from_account, class_name: "StoredValueAccount"
  belongs_to :to_account, class_name: "StoredValueAccount"
  belongs_to :transfer_out_entry, class_name: "StoredValueLedgerEntry"
  belongs_to :transfer_in_entry, class_name: "StoredValueLedgerEntry"
  belongs_to :reason_code, class_name: "StoredValueReasonCode"
  belongs_to :created_by_user, class_name: "User"

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validate :accounts_must_differ

  private

  def accounts_must_differ
    return if from_account_id.blank? || to_account_id.blank?
    return unless from_account_id == to_account_id

    errors.add(:to_account, "must differ from source account")
  end
end
