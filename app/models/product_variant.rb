# frozen_string_literal: true

class ProductVariant < ApplicationRecord
  include ReturnabilityStatus

  INVENTORY_BEHAVIORS = %w[
    standard_physical digital_asset drop_ship composite_recipe
    capacitated_service pure_financial non_inventory
  ].freeze

  belongs_to :product
  belongs_to :condition, class_name: "ProductCondition", optional: true
  belongs_to :sub_department
  belongs_to :display_location, optional: true
  belongs_to :preferred_vendor, class_name: "Vendor", optional: true
  belongs_to :created_from_buyback_session, class_name: "BuybackSession", optional: true

  has_many :categorizations, as: :categorizable, dependent: :destroy
  has_many :product_variant_vendors, dependent: :restrict_with_error

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :short_name, length: { maximum: 40 }, allow_blank: true
  validates :selling_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :inventory_behavior, presence: true, inclusion: { in: INVENTORY_BEHAVIORS }
  validates :inventory_tracking_override,
    inclusion: { in: Inventory::TrackingResolver::TRACKING_VALUES },
    allow_nil: true
  validates :returnability_status, presence: true, inclusion: { in: ReturnabilityStatus::RETURNABILITY_STATUSES }
  validates :orderable, inclusion: { in: [ true, false ] }
  validates :pricing_model_override, inclusion: { in: PricingModels::PRICING_MODELS }, allow_blank: true
  validates :attribute1_sku_component, length: { maximum: 5 }, allow_blank: true
  validates :attribute2_sku_component, length: { maximum: 5 }, allow_blank: true
  validate :condition_must_be_active
  validate :sub_department_must_be_active
  validate :display_location_must_be_active
  validate :product_must_be_active
  validate :preferred_vendor_must_be_active

  scope :active_records, -> { where(active: true) }

  before_validation :normalize_strings
  before_validation :apply_generated_fields, on: :create
  before_validation :apply_orderability_default, on: :create

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  def rendered_name
    ProductNameRenderer.variant_name(self)
  end

  def list_label
    ProductNameRenderer.variant_list_label(self)
  end

  def inventory_tracking
    Inventory::TrackingResolver.resolve(self)
  end

  def resolved_sub_department
    sub_department
  end

  private

  def normalize_strings
    self.name = name&.strip
    self.name_override = name_override&.strip.presence
    self.short_name = short_name&.strip.presence
    self.sku = sku&.strip&.upcase
    self.attribute1_value = attribute1_value&.strip.presence
    self.attribute1_sku_component = attribute1_sku_component&.strip&.upcase.presence
    self.attribute2_value = attribute2_value&.strip.presence
    self.attribute2_sku_component = attribute2_sku_component&.strip&.upcase.presence
  end

  def apply_generated_fields
    generated_sku = SkuGenerator.variant_sku(self)
    if sku.blank? || (condition&.sku_component.present? && sku == product.sku)
      self.sku = generated_sku
    end
    self.name = ProductNameRenderer.variant_name(self) if name.blank?
  end

  def apply_orderability_default
    return if orderable_changed?

    ProductVariants::OrderabilityDefaults.apply!(self)
  end

  def condition_must_be_active
    return if condition.blank? || condition.active?

    errors.add(:condition, "must be active")
  end

  def sub_department_must_be_active
    return if sub_department.blank? || sub_department.active?

    errors.add(:sub_department, "must be active")
  end

  def display_location_must_be_active
    return if display_location.blank? || display_location.active?

    errors.add(:display_location, "must be active")
  end

  def product_must_be_active
    return if product.blank? || product.active?

    errors.add(:product, "must be active")
  end

  def preferred_vendor_must_be_active
    return if preferred_vendor.blank? || preferred_vendor.active?

    errors.add(:preferred_vendor, "must be active")
  end
end
