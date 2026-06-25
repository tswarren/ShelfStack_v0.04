# frozen_string_literal: true

class DiscountReason < ApplicationRecord
  has_many :pos_discount_applications, dependent: :restrict_with_error

  validates :reason_key, presence: true, uniqueness: true, length: { maximum: 40 }
  validates :name, presence: true, uniqueness: true
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active_records, -> { where(active: true) }

  before_validation :normalize_strings

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  private

  def normalize_strings
    self.reason_key = reason_key&.strip&.downcase
    self.name = name&.strip
  end
end
