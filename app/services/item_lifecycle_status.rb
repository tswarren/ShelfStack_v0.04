# frozen_string_literal: true

class ItemLifecycleStatus
  BASIC_STATUSES = %w[
    catalog_only
    product_created
    sellable
    no_active_variant
    invalid_identifier_warning
  ].freeze

  FULL_STATUSES = %w[
    missing_category
    missing_merchandise_class
    missing_accounting_mapping
    missing_price
    inactive_setup_reference
  ].freeze

  def self.basic(presenter)
    new(presenter).basic
  end

  def self.full(presenter)
    new(presenter).full
  end

  def initialize(presenter)
    @presenter = presenter
  end

  def basic
    statuses = []
    if @presenter.catalog_item && @presenter.product.blank?
      statuses << "catalog_only"
    elsif @presenter.product && !@presenter.sellable?
      statuses << (@presenter.product.product_variants.exists? ? "no_active_variant" : "product_created")
    elsif @presenter.sellable?
      statuses << "sellable"
    end

    statuses << "invalid_identifier_warning" if invalid_identifier?
    statuses.uniq
  end

  def full
    (basic + detail_statuses).uniq
  end

  private

  def detail_statuses
    statuses = []
    @presenter.variants.each do |variant|
      statuses << "missing_category" if variant.category.blank?
      statuses << "missing_merchandise_class" if variant.category.present? && variant.category.merchandise_class.blank?
      resolved = ClassificationDefaultsResolver.for(variant: variant)
      statuses << "missing_accounting_mapping" if resolved.sales_account_code.blank?
      statuses << "missing_price" if variant.selling_price_cents.blank?
      statuses << "inactive_setup_reference" if inactive_setup_reference?(variant)
    end
    statuses.uniq
  end

  def invalid_identifier?
    return false if @presenter.catalog_item.blank?

    @presenter.catalog_item.catalog_item_identifiers.active_records.any? do |identifier|
      identifier.valid_check_digit == false
    end
  end

  def inactive_setup_reference?(variant)
    (variant.category.present? && !variant.category.active?) ||
      (variant.condition.present? && !variant.condition.active?) ||
      (variant.display_location.present? && !variant.display_location.active?)
  end
end
