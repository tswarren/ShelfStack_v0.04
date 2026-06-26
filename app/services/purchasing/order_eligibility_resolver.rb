# frozen_string_literal: true

module Purchasing
  class OrderEligibilityResolver
    BLOCKING_PRODUCT_TYPES = %w[service financial].freeze
    DISCONTINUED_STATUSES = %w[discontinued publication_cancelled].freeze

    Reason = Data.define(:code, :message, :severity)

    Result = Data.define(:eligible, :requires_override, :blocking_reasons, :warnings, :infos) do
      def blocking?
        blocking_reasons.any?
      end

      def submit_blocked?
        blocking_reasons.any? { |reason| reason.severity == :blocking }
      end
    end

    def self.call(product_variant:, vendor: nil, context: :purchase_order, store: nil)
      new(product_variant:, vendor:, context:, store:).call
    end

    def self.for_variants(store:, variants:, context: :item_page, vendors_by_variant_id: nil)
      variants = Array(variants).compact
      return {} if variants.empty?

      vendors_by_variant_id ||= SuggestedVendorResolver.for_variants(variants.map(&:id))
        .transform_values { |result| result.vendor }

      variants.index_with do |variant|
        call(
          product_variant: variant,
          vendor: vendors_by_variant_id[variant.id],
          context: context,
          store: store
        )
      end
    end

    def initialize(product_variant:, vendor: nil, context: :purchase_order, store: nil)
      @product_variant = product_variant
      @vendor = vendor
      @context = context.to_sym
      @store = store
    end

    def call
      blocking = []
      warnings = []
      infos = []

      evaluate_common_rules(blocking:, warnings:, infos:)
      evaluate_context_rules(blocking:, warnings:, infos:)

      Result.new(
        eligible: blocking.empty?,
        requires_override: false,
        blocking_reasons: blocking,
        warnings: warnings,
        infos: infos
      )
    end

    private

    attr_reader :product_variant, :vendor, :context, :store

    def evaluate_common_rules(blocking:, warnings:, infos:)
      return blocking << reason(:missing_variant, :blocking) if product_variant.blank?

      product = product_variant.product
      if product.blank? || !product.active?
        blocking << reason(:inactive_product, :blocking)
      end
      blocking << reason(:inactive_variant, :blocking) unless product_variant.active?
      blocking << reason(:inactive_vendor, :blocking) if vendor.present? && !vendor.active?

      if context == :tbo
        blocking << reason(:gift_card_or_non_merchandise, :blocking) if non_merchandise_product_type?
        return
      end

      if item_page_context?
        evaluate_item_page_rules(blocking:, warnings:, infos:)
        return
      end

      blocking << reason(:gift_card_or_non_merchandise, :blocking) if non_merchandise_product_type?
      blocking << reason(:used_variant, :blocking) if used_variant?
      blocking << reason(:not_orderable, :blocking) unless product_variant.orderable?
      blocking << reason(:non_inventory_not_orderable, :blocking) if non_inventory_blocked?

      if discontinued_catalog_item?
        warnings << reason(:discontinued_catalog_item, :warning)
        blocking << reason(:discontinued_catalog_item_submit_block, :blocking) if context == :purchase_order_submit
      end

      evaluate_vendor_sourcing(warnings:, infos:)
    end

    def evaluate_item_page_rules(blocking:, warnings:, infos:)
      blocking << reason(:gift_card_or_non_merchandise, :blocking) if non_merchandise_product_type?
      warnings << reason(:used_variant, :warning) if used_variant?
      warnings << reason(:not_orderable, :warning) unless product_variant.orderable?
      warnings << reason(:non_inventory_not_orderable, :warning) if non_inventory_blocked?

      if discontinued_catalog_item?
        warnings << reason(:discontinued_catalog_item, :warning)
      end

      evaluate_vendor_sourcing(warnings:, infos:)
    end

    def evaluate_vendor_sourcing(warnings:, infos:)
      if vendor.present?
        sourcing = SourcingLookup.for(variant: product_variant, vendor: vendor)
        warnings << reason(:missing_vendor_source, :warning) unless sourcing.sourcing_record_present
      end

      warnings << reason(:missing_preferred_vendor, :warning) if SuggestedVendorResolver.for_variant(product_variant).vendor.blank?
      warnings << reason(:missing_cost, :warning) if missing_cost?
      infos << reason(:missing_identifier, :info) if missing_identifier?
    end

    def evaluate_context_rules(blocking:, warnings:, infos:)
      # reserved for future TBO-specific differences beyond common rules
    end

    def item_page_context?
      context == :item_page
    end

    def used_variant?
      product_variant.condition.present? && !product_variant.condition.new_condition?
    end

    def non_merchandise_product_type?
      BLOCKING_PRODUCT_TYPES.include?(product_variant.product&.product_type)
    end

    def non_inventory_blocked?
      product_variant.product&.product_type == "non_inventory" && !product_variant.orderable?
    end

    def discontinued_catalog_item?
      catalog_item = product_variant.product&.catalog_item
      return false if catalog_item.blank?

      DISCONTINUED_STATUSES.include?(catalog_item.publication_status)
    end

    def missing_cost?
      variant = product_variant
      vendor_for_lookup = vendor || SuggestedVendorResolver.for_variant(variant).vendor
      return true if vendor_for_lookup.blank?

      sourcing = SourcingLookup.for(variant: variant, vendor: vendor_for_lookup)
      list = variant.product&.list_price_cents
      cost = VendorCostCalculator.unit_cost_cents(
        unit_list_price_cents: list,
        supplier_discount_bps: sourcing.supplier_discount_bps
      )
      cost.nil?
    end

    def missing_identifier?
      catalog_item = product_variant.product&.catalog_item
      return false if catalog_item.blank?

      !catalog_item.catalog_item_identifiers.active_records.exists?
    end

    def reason(code, severity)
      Reason.new(code: code, message: REASON_MESSAGES.fetch(code), severity: severity)
    end

    REASON_MESSAGES = {
      missing_variant: "Variant is required.",
      inactive_product: "Product is inactive.",
      inactive_variant: "Variant is inactive.",
      inactive_vendor: "Vendor is inactive.",
      gift_card_or_non_merchandise: "This item type cannot be added to a vendor purchase order.",
      used_variant: "Used variants cannot be added to normal vendor purchase orders.",
      not_orderable: "This variant is not orderable from vendors.",
      non_inventory_not_orderable: "Non-inventory variants require explicit orderable flag.",
      discontinued_catalog_item: "Catalog item is discontinued or publication cancelled.",
      discontinued_catalog_item_submit_block: "Discontinued items cannot be submitted on a purchase order.",
      missing_vendor_source: "No vendor sourcing record exists for this item and vendor.",
      missing_preferred_vendor: "No preferred vendor is configured.",
      missing_cost: "Expected unit cost could not be determined.",
      missing_identifier: "No active catalog identifier is on file."
    }.freeze
    private_constant :REASON_MESSAGES
  end
end
