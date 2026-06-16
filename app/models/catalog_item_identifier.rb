# frozen_string_literal: true

class CatalogItemIdentifier < ApplicationRecord
  IDENTIFIER_TYPES = %w[isbn10 isbn13 ean upc gtin publisher_number local].freeze
  STANDARD_TYPES = %w[isbn10 isbn13 ean upc gtin].freeze

  belongs_to :catalog_item

  validates :identifier_type, presence: true, inclusion: { in: IDENTIFIER_TYPES }
  validates :identifier_value, presence: true, length: { maximum: 100 }
  validates :normalized_identifier, presence: true, length: { maximum: 100 }
  validates :normalized_identifier, uniqueness: {
    scope: :identifier_type,
    conditions: -> { where(identifier_type: STANDARD_TYPES + [ "local" ]) }
  }

  scope :active_records, -> { where(active: true) }
  scope :primary_records, -> { active_records.where(primary_identifier: true) }

  before_validation :normalize_sku_component_fields

  def inactivate!
    update!(active: false, primary_identifier: false)
  end

  def reactivate!
    update!(active: true)
  end

  private

  def normalize_sku_component_fields
    self.source = source&.strip.presence
  end
end
