# frozen_string_literal: true

class BuybackVoid < ApplicationRecord
  belongs_to :buyback_session
  belongs_to :store
  belongs_to :workstation
  belongs_to :pos_register_session, optional: true
  belongs_to :voided_by_user, class_name: "User"
  belongs_to :pos_authorization, optional: true
  belongs_to :inventory_posting, optional: true, class_name: "InventoryPosting"
  belongs_to :void_stored_value_ledger_entry, optional: true, class_name: "StoredValueLedgerEntry"
  belongs_to :void_cash_movement, optional: true, class_name: "PosCashMovement"

  has_one :inventory_posting_as_source, as: :source, class_name: "InventoryPosting", dependent: :restrict_with_error

  validates :voided_at, presence: true
  validates :void_reason, presence: true
  validates :buyback_session_id, uniqueness: true
end
