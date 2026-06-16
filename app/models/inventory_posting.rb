# frozen_string_literal: true

class InventoryPosting < ApplicationRecord
  POSTING_TYPES = %w[
    opening_inventory manual_adjustment balance_correction
    receiving pos_sale customer_return vendor_return used_buyback transfer
  ].freeze

  PHASE4_POSTING_TYPES = %w[opening_inventory manual_adjustment balance_correction].freeze

  belongs_to :source, polymorphic: true
  belongs_to :store
  belongs_to :posted_by_user, class_name: "User"
  belongs_to :workstation, optional: true
  belongs_to :reversal_of_posting, class_name: "InventoryPosting", optional: true
  belongs_to :reversed_by_posting, class_name: "InventoryPosting", optional: true

  has_many :inventory_ledger_entries, dependent: :restrict_with_error
  has_one :inventory_adjustment, dependent: :nullify
  has_many :inventory_balances_as_last, class_name: "InventoryBalance",
           foreign_key: :last_posting_id, dependent: :nullify, inverse_of: :last_posting

  validates :posting_type, presence: true, inclusion: { in: POSTING_TYPES }
  validates :source, presence: true
  validates :posted_at, presence: true
  validates :idempotency_key, presence: true, uniqueness: true

  scope :for_store, ->(store) { where(store: store) }
end
