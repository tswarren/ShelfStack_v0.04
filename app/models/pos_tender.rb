# frozen_string_literal: true

class PosTender < ApplicationRecord
  TENDER_TYPES = %w[cash card check gift_card store_credit].freeze
  PHASE6_ALLOWED_TYPES = %w[cash card check].freeze

  belongs_to :pos_transaction
  belongs_to :reverses_tender, class_name: "PosTender", optional: true
  has_one :reversed_by_tender, class_name: "PosTender", foreign_key: :reverses_tender_id,
                               inverse_of: :reverses_tender, dependent: :nullify

  validates :tender_type, presence: true, inclusion: { in: TENDER_TYPES }
  validates :amount_cents, numericality: { only_integer: true }
end
