# frozen_string_literal: true

class InternalEanSequence < ApplicationRecord
  ACTIVE_V0042_PAIRS = {
    "201" => "product_house",
    "211" => "variant_sku"
  }.freeze

  validates :segment, presence: true, length: { is: 3 }, format: { with: /\A[0-9]{3}\z/ }
  validates :purpose, presence: true
  validates :last_sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :segment, uniqueness: true
  validate :segment_purpose_pair_allowed

  scope :active_records, -> { where(active: true) }

  private

  def segment_purpose_pair_allowed
    expected = ACTIVE_V0042_PAIRS[segment]
    return if expected.blank? && !active?

    if expected.blank?
      errors.add(:segment, "is not an active v0.04-2 segment")
      return
    end

    return if purpose == expected

    errors.add(:purpose, "must be #{expected} for segment #{segment}")
  end
end
