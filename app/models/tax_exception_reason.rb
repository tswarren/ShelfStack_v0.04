# frozen_string_literal: true

class TaxExceptionReason < ApplicationRecord
  EXCEPTION_TYPES = %w[exemption rate_override both].freeze

  has_many :pos_tax_exemptions, dependent: :restrict_with_error
  has_many :pos_line_tax_overrides, dependent: :restrict_with_error

  validates :reason_key, presence: true, uniqueness: true, length: { maximum: 40 }
  validates :name, presence: true, uniqueness: true
  validates :exception_type, presence: true, inclusion: { in: EXCEPTION_TYPES }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active_records, -> { where(active: true) }
  scope :for_exemption, -> { where(exception_type: %w[exemption both]) }
  scope :for_rate_override, -> { where(exception_type: %w[rate_override both]) }

  before_validation :normalize_strings

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  def allows_exemption?
    exception_type.in?(%w[exemption both])
  end

  def allows_rate_override?
    exception_type.in?(%w[rate_override both])
  end

  private

  def normalize_strings
    self.reason_key = reason_key&.strip&.downcase
    self.name = name&.strip
  end
end
