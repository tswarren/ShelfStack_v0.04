# frozen_string_literal: true

class PosTender < ApplicationRecord
  TENDER_TYPES = %w[cash card check gift_card store_credit].freeze
  PHASE6_ALLOWED_TYPES = %w[cash card check].freeze
  STORED_VALUE_TENDER_TYPES = Pos::StoredValueTenderSupport::STORED_VALUE_TENDER_TYPES
  CARD_BRANDS = %w[visa mastercard american_express discover debit other].freeze
  TENDERED_REFERENCE_PREFIX = "tendered_cents:"

  belongs_to :pos_transaction
  belongs_to :reverses_tender, class_name: "PosTender", optional: true
  belongs_to :stored_value_account, class_name: "StoredValueAccount", optional: true
  belongs_to :stored_value_identifier, class_name: "StoredValueIdentifier", optional: true
  has_one :reversed_by_tender, class_name: "PosTender", foreign_key: :reverses_tender_id,
                               inverse_of: :reverses_tender, dependent: :nullify
  has_many :stored_value_ledger_entries, as: :source, dependent: :restrict_with_error

  validates :tender_type, presence: true, inclusion: { in: TENDER_TYPES }
  validates :amount_cents, numericality: { only_integer: true }
  validates :line_number, presence: true, uniqueness: { scope: :pos_transaction_id }
  validates :card_brand, presence: true, inclusion: { in: CARD_BRANDS }, if: :card_tender?
  validates :card_last_four, format: { with: /\A\d{4}\z/ }, allow_blank: true
  validates :stored_value_account, presence: true, if: :stored_value_account_required?
  validate :stored_value_account_compatible_with_tender, if: :stored_value_tender?
  validate :stored_value_tender_has_no_cash_fields, if: :stored_value_tender?

  scope :settlement_rows, -> { where(reverses_tender_id: nil) }
  scope :for_transaction, ->(transaction) { where(pos_transaction: transaction) }

  def card_tender?
    tender_type == "card"
  end

  def cash_tender?
    tender_type == "cash"
  end

  def stored_value_tender?
    STORED_VALUE_TENDER_TYPES.include?(tender_type)
  end

  def stored_value_account_required?
    stored_value_tender? && pos_transaction&.customer_id.blank?
  end

  def issue_tender?(transaction = pos_transaction)
    Pos::StoredValueTenderSupport.issue_tender?(transaction:, tender: self)
  end

  def redeem_tender?(transaction = pos_transaction)
    Pos::StoredValueTenderSupport.redeem_tender?(transaction:, tender: self)
  end

  def reversal_row?
    reverses_tender_id.present?
  end

  def tendered_display_cents
    return tendered_cents if tendered_cents.present?

    legacy_tendered_cents_from_reference || amount_cents
  end

  def change_display_cents
    return change_cents if change_cents.present?

    tendered = tendered_display_cents
    return 0 unless cash_tender? && tendered > amount_cents

    tendered - amount_cents
  end

  def self.next_line_number_for(transaction)
    (transaction.pos_tenders.maximum(:line_number) || 0) + 1
  end

  private

  def stored_value_account_compatible_with_tender
    return if stored_value_account.blank?

    unless Pos::StoredValueTenderSupport.account_compatible_with_tender?(account: stored_value_account, tender_type:)
      errors.add(:stored_value_account, "account type is not compatible with #{tender_type} tender")
    end
  end

  def stored_value_tender_has_no_cash_fields
    return unless tendered_cents.present? || change_cents.present?

    errors.add(:base, "Stored value tenders cannot have tendered or change amounts")
  end

  def legacy_tendered_cents_from_reference
    reference = reference_number.to_s
    return unless reference.start_with?(TENDERED_REFERENCE_PREFIX)

    reference.delete_prefix(TENDERED_REFERENCE_PREFIX).to_i
  end
end
