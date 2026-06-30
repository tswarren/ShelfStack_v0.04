# frozen_string_literal: true

class ProductVariantLookupCode < ApplicationRecord
  CODE_TYPES = %w[manual plu menu_key legacy alias].freeze
  MIN_CODE_LENGTH = 2
  MAX_CODE_LENGTH = 12

  belongs_to :product_variant
  belongs_to :store, optional: true

  validates :code, presence: true, length: { in: MIN_CODE_LENGTH..MAX_CODE_LENGTH }
  validates :normalized_code, presence: true, length: { in: MIN_CODE_LENGTH..MAX_CODE_LENGTH }
  validates :code_type, presence: true, inclusion: { in: CODE_TYPES }

  scope :active_records, -> { where(active: true) }

  before_validation :normalize_code_fields

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  private

  def normalize_code_fields
    self.code = code&.strip&.upcase
    self.normalized_code = self.class.normalize_lookup_code(code)
    self.code_type = code_type&.strip.presence || "manual"
  end

  def self.normalize_lookup_code(value)
    cleaned = value.to_s.strip.upcase.gsub(/[^A-Z0-9-]/, "")
    cleaned.presence
  end
end
