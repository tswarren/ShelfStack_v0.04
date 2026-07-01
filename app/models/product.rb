# frozen_string_literal: true

class Product < ApplicationRecord
  include ProductMetadata

  PRODUCT_TYPES = %w[physical digital service non_inventory financial].freeze
  VARIATION_TYPES = %w[standard conditional variable matrix].freeze

  # Path B transitional bridge — do not set on new product-first creates after v0.04-1.
  belongs_to :catalog_item, optional: true
  belongs_to :default_display_location, class_name: "DisplayLocation", optional: true
  belongs_to :default_sub_department, class_name: "SubDepartment", optional: true
  belongs_to :created_from_buyback_session, class_name: "BuybackSession", optional: true
  belongs_to :preferred_vendor, class_name: "Vendor", optional: true
  has_many :product_variants, dependent: :restrict_with_error
  has_many :product_identifiers, dependent: :restrict_with_error
  has_many :product_vendors, dependent: :restrict_with_error
  has_one_attached :cover_image

  ALLOWED_COVER_IMAGE_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  MAX_COVER_IMAGE_SIZE = 5.megabytes

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :short_name, length: { maximum: 40 }, allow_blank: true
  validates :product_type, presence: true, inclusion: { in: PRODUCT_TYPES }
  validates :variation_type, presence: true, inclusion: { in: VARIATION_TYPES }
  validates :list_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :default_inventory_tracking,
    inclusion: { in: Inventory::TrackingResolver::TRACKING_VALUES },
    allow_nil: true
  validate :catalog_item_must_be_active, if: -> { catalog_item_id.present? }
  validate :default_display_location_must_be_active
  validate :default_sub_department_must_be_active
  validate :preferred_vendor_must_be_active
  validate :cover_image_must_be_valid, if: -> { cover_image.attached? }

  scope :active_records, -> { where(active: true) }

  before_validation :normalize_strings
  before_validation :apply_product_defaults, on: :create

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  def sellable?
    product_variants.active_records.exists?
  end

  def primary_identifier
    product_identifiers.primary_records.first
  end

  def active_identifiers
    product_identifiers.active_records
  end

  def rendered_name
    ProductNameRenderer.product_name(self)
  end

  def catalog_linked?
    catalog_item_id.present?
  end

  def latest_external_catalog_import
    ExternalCatalogImport.applied_imports
      .where(product_id: id)
      .order(applied_at: :desc, id: :desc)
      .first
  end

  private

  def normalize_strings
    self.name = name&.strip
    self.name_override = name_override&.strip.presence
    self.short_name = short_name&.strip.presence
    self.sku = sku&.strip&.upcase
    self.variant1_label = variant1_label&.strip.presence
    self.variant2_label = variant2_label&.strip.presence
  end

  def apply_product_defaults
    if catalog_item.present?
      Products::CopyCatalogMetadata.to_product(self, catalog_item) unless metadata_fused?
      self.name = ProductNameRenderer.product_name(self) if name.blank?
      if sku.blank?
        self.sku = if product_identifiers.active_records.exists? || primary_identifier.present?
          SkuGenerator.product_sku(self)
        else
          AddItem::ProductSkuGenerator.generate!
        end
      end
      return
    end

    self.name = ProductNameRenderer.product_name(self) if name.blank? && title.present?
    self.title = name if title.blank? && name.present?
    self.sku = AddItem::ProductSkuGenerator.generate! if sku.blank? && title.present?
  end

  def catalog_item_must_be_active
    return if catalog_item.blank? || catalog_item.active?

    errors.add(:catalog_item, "must be active")
  end

  def default_display_location_must_be_active
    return if default_display_location.blank? || default_display_location.active?

    errors.add(:default_display_location, "must be active")
  end

  def default_sub_department_must_be_active
    return if default_sub_department.blank? || default_sub_department.active?

    errors.add(:default_sub_department, "must be active")
  end

  def preferred_vendor_must_be_active
    return if preferred_vendor.blank? || preferred_vendor.active?

    errors.add(:preferred_vendor, "must be active")
  end

  def cover_image_must_be_valid
    unless ALLOWED_COVER_IMAGE_TYPES.include?(cover_image.blob.content_type)
      errors.add(:cover_image, "must be a JPEG, PNG, WebP, or GIF")
    end

    return if cover_image.blob.byte_size <= MAX_COVER_IMAGE_SIZE

    errors.add(:cover_image, "must be smaller than 5 MB")
  end
end
