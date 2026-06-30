# frozen_string_literal: true

class ProductIdentifier < ApplicationRecord
  VALIDATION_FAMILIES = %w[gtin isbn freeform house].freeze
  FREEFORM_SCOPES = %w[
    legacy_local
    legacy_product_sku
    publisher_number
    bipad
    vendor_catalog
    import_reference
  ].freeze

  belongs_to :product

  validates :validation_family, presence: true, inclusion: { in: VALIDATION_FAMILIES }
  validates :identifier_value, presence: true, length: { maximum: 100 }
  validates :normalized_identifier, presence: true, length: { maximum: 100 }
  validates :source, presence: true
  validates :freeform_scope, inclusion: { in: FREEFORM_SCOPES }, allow_nil: true
  validate :freeform_scope_required_for_freeform_family

  scope :active_records, -> { where(active: true) }
  scope :primary_records, -> { active_records.where(primary_identifier: true) }

  before_validation :normalize_string_fields

  def inactivate!
    update!(active: false, primary_identifier: false)
  end

  def reactivate!
    update!(active: true)
  end

  def gtin_family?
    validation_family == "gtin" || validation_family == "house"
  end

  private

  def normalize_string_fields
    self.source = source&.strip.presence || "manual"
    self.display_label = display_label&.strip.presence
    self.freeform_scope = freeform_scope&.strip.presence
  end

  def freeform_scope_required_for_freeform_family
    return unless validation_family == "freeform"
    return if freeform_scope.present?

    errors.add(:freeform_scope, "is required for freeform identifiers")
  end
end
