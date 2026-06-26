# frozen_string_literal: true

module Items
  class OperationalWarningBuilder
    include Rails.application.routes.url_helpers

    Warning = Data.define(:severity, :category, :code, :message, :variant_id, :corrective_path, :corrective_label, :source) do
      def action_path
        corrective_path
      end

      def action_label
        corrective_label
      end
    end

    SEVERITY_ORDER = { blocking: 0, warning: 1, info: 2 }.freeze

    def self.call(product_variant: nil, item: nil, store: nil, user: nil, contexts: %i[ordering data_quality], vendor: nil, snapshot: nil)
      if item.present?
        for_item(item:, store:, user:, contexts:, snapshot:).flat_map { |_key, warnings| warnings }
      else
        new(product_variant:, contexts:, vendor:, store:).variant_warnings(product_variant)
      end
    end

    def self.for_item(item:, store:, user:, contexts: default_contexts, snapshot: nil, eligibility_by_variant: nil)
      variants = item.variants.to_a
      snapshot ||= VariantOperationalSnapshot.for_variants(store:, variants:, user:, item:)
      variant_warnings = for_variants(
        store:,
        variants:,
        contexts:,
        snapshot:,
        item:,
        eligibility_by_variant:
      )

      item_warnings = new(item:, store:, user:, contexts:, snapshot:).item_level_warnings
      { item => item_warnings + variant_warnings.values.flatten }
    end

    def self.for_variants(store:, variants:, contexts: default_contexts, snapshot: nil, item: nil, vendors_by_variant_id: nil, eligibility_by_variant: nil)
      variants = Array(variants).compact
      return {} if variants.empty?

      snapshot ||= VariantOperationalSnapshot.for_variants(store:, variants:, item:, user: nil)
      vendors_by_variant_id ||= snapshot.suggested_vendors.transform_values { |result| result.vendor }
      eligibility_by_variant ||= if contexts.include?(:ordering)
        Purchasing::OrderEligibilityResolver.for_variants(
          store:,
          variants:,
          context: :item_page,
          vendors_by_variant_id:,
          sourcing_by_variant_id: snapshot.sourcing_by_variant_id,
          suggested_vendors_by_variant_id: snapshot.suggested_vendors
        )
      else
        {}
      end

      variants.each_with_object({}) do |variant, results|
        row = snapshot.rows[variant.id]
        results[variant.id] = new(
          product_variant: variant,
          contexts:,
          store:,
          item:,
          snapshot:,
          row:,
          eligibility_result: eligibility_by_variant[variant.id]
        ).variant_warnings(variant, vendor: vendors_by_variant_id[variant.id])
      end
    end

    def self.for_items(store:, items:, user:, contexts: default_contexts)
      items = Array(items).compact
      return {} if items.empty?

      all_variants = items.flat_map { |item| item.variants.to_a }.uniq
      snapshot = VariantOperationalSnapshot.for_variants(store:, variants: all_variants, user:, item: nil)
      variant_warnings = for_variants(store:, variants: all_variants, contexts:, snapshot:)

      items.index_with do |item|
        item_variants = item.variants.to_a
        builder = new(item:, store:, user:, contexts:, snapshot:)
        builder.item_level_warnings + item_variants.flat_map { |variant| variant_warnings.fetch(variant.id, []) }
      end
    end

    def self.worst_severity(warnings)
      warnings.min_by { |warning| SEVERITY_ORDER.fetch(warning.severity, 99) }&.severity
    end

    def self.counts_by_severity(warnings)
      warnings.group_by(&:severity).transform_values(&:count)
    end

    def self.default_contexts
      %i[selling ordering inventory data_quality]
    end

    def initialize(product_variant: nil, item: nil, store: nil, user: nil, contexts: default_contexts, vendor: nil, snapshot: nil, row: nil, eligibility_result: nil)
      @product_variant = product_variant
      @item = item
      @store = store
      @user = user
      @contexts = Array(contexts).map(&:to_sym)
      @vendor = vendor
      @snapshot = snapshot
      @row = row
      @eligibility_result = eligibility_result
    end

    def variant_warnings(variant = product_variant, vendor: @vendor)
      warnings = []
      warnings.concat(ordering_warnings(variant, vendor)) if contexts.include?(:ordering)
      warnings.concat(selling_warnings(variant)) if contexts.include?(:selling)
      warnings.concat(inventory_warnings(variant)) if contexts.include?(:inventory)
      warnings.concat(data_quality_warnings(variant)) if contexts.include?(:data_quality)
      warnings
    end

    def item_level_warnings
      warnings = []
      warnings.concat(open_tbo_warnings) if contexts.include?(:ordering) && snapshot.present?
      warnings.concat(identifier_warnings) if contexts.include?(:data_quality) && item.present?
      warnings.concat(missing_catalog_thumbnail_warnings) if contexts.include?(:data_quality) && item.present?
      warnings
    end

    private

    attr_reader :product_variant, :item, :store, :user, :contexts, :vendor, :snapshot, :row, :eligibility_result

    def ordering_warnings(variant, vendor)
      result = eligibility_result || Purchasing::OrderEligibilityResolver.call(
        product_variant: variant,
        vendor: vendor || snapshot&.suggested_vendors&.dig(variant.id)&.vendor,
        context: :item_page,
        store: store,
        sourcing: snapshot&.sourcing_by_variant_id&.[](variant.id),
        suggested_vendor_result: snapshot&.suggested_vendors&.[](variant.id)
      )

      (result.blocking_reasons + result.warnings + result.infos).map do |reason|
        build_warning(
          severity: reason.severity,
          category: :ordering,
          code: reason.code,
          message: reason.message,
          variant_id: variant.id,
          source: :order_eligibility,
          corrective_path: action_for(reason.code, variant)&.dig(:path),
          corrective_label: action_for(reason.code, variant)&.dig(:label)
        )
      end
    end

    def selling_warnings(variant)
      warnings = []
      if variant.selling_price_cents.to_i.zero?
        warnings << build_warning(
          severity: :warning,
          category: :selling,
          code: :missing_price,
          message: "Missing selling price.",
          variant_id: variant.id,
          corrective_path: edit_items_product_variant_path(variant, return_to: "item"),
          corrective_label: "Edit SKU",
          source: :variant_setup
        )
      end

      if variant.sub_department_id.blank?
        warnings << build_warning(
          severity: :warning,
          category: :selling,
          code: :missing_subdepartment,
          message: "Missing subdepartment.",
          variant_id: variant.id,
          corrective_path: edit_items_product_variant_path(variant, return_to: "item"),
          corrective_label: "Edit SKU",
          source: :variant_setup
        )
      end

      if variant.display_location_id.blank? && item&.product&.default_display_location_id.blank?
        warnings << build_warning(
          severity: :info,
          category: :selling,
          code: :missing_display_location,
          message: "No display location configured.",
          variant_id: variant.id,
          corrective_path: item&.tab_path("item_setup"),
          corrective_label: "Item setup",
          source: :variant_setup
        )
      end

      returnability = row&.returnability_status
      if returnability.present? && returnability != "returnable"
        warnings << build_warning(
          severity: :warning,
          category: :selling,
          code: :non_returnable,
          message: "#{returnability.humanize} returnability.",
          variant_id: variant.id,
          corrective_path: Items::VendorSourcingPath.for(variant),
          corrective_label: "Review sourcing",
          source: :returnability
        )
      end

      warnings
    end

    def inventory_warnings(variant)
      warnings = []
      tracking = Inventory::TrackingResolver.resolve(variant)
      if tracking == "non_inventory" && row&.on_hand.to_i.positive?
        warnings << build_warning(
          severity: :warning,
          category: :inventory,
          code: :non_inventory_with_stock,
          message: "Non-inventory variant has on-hand stock.",
          variant_id: variant.id,
          corrective_path: edit_items_product_variant_path(variant, return_to: "item"),
          corrective_label: "Edit SKU",
          source: :inventory_tracking
        )
      end

      if inventory_tracking_mismatch?(variant)
        warnings << build_warning(
          severity: :warning,
          category: :inventory,
          code: :inventory_tracking_mismatch,
          message: "Inventory tracking override conflicts with product default or legacy behavior.",
          variant_id: variant.id,
          corrective_path: edit_items_product_variant_path(variant, return_to: "item"),
          corrective_label: "Edit SKU",
          source: :inventory_tracking
        )
      end

      warnings
    end

    def inventory_tracking_mismatch?(variant)
      signals = {}
      if variant.inventory_tracking_override.present?
        signals[:override] = variant.inventory_tracking_override
      end
      if variant.inventory_behavior.present?
        signals[:behavior] = Inventory::TrackingResolver.tracking_for_behavior(variant.inventory_behavior)
      end
      if variant.product&.default_inventory_tracking.present?
        signals[:product_default] = variant.product.default_inventory_tracking
      end

      return false if signals.size < 2

      signals.values.uniq.size > 1
    end

    def data_quality_warnings(variant)
      catalog_item = variant.product&.catalog_item
      return [] if catalog_item.blank?

      if catalog_item.catalog_item_identifiers.active_records.none?
        [
          build_warning(
            severity: :info,
            category: :data_quality,
            code: :missing_identifier,
            message: "No active catalog identifier on file.",
            variant_id: variant.id,
            corrective_path: item&.tab_path("item_setup"),
            corrective_label: "Review identifiers",
            source: :catalog
          )
        ]
      else
        []
      end
    end

    def open_tbo_warnings
      total_tbo = snapshot.rows.values.sum { |entry| entry.open_tbo.to_i }
      return [] unless total_tbo.positive?

      [
        build_warning(
          severity: :info,
          category: :ordering,
          code: :open_tbo,
          message: "#{total_tbo} open TBO #{'unit'.pluralize(total_tbo)} are not yet fully on purchase orders.",
          variant_id: nil,
          corrective_path: item.tab_path("operations"),
          corrective_label: "View operations",
          source: :tbo
        )
      ]
    end

    def identifier_warnings
      return [] unless item.full_statuses.include?("invalid_identifier_warning")

      [
        build_warning(
          severity: :warning,
          category: :data_quality,
          code: :invalid_identifier,
          message: "Primary or secondary identifier needs review.",
          variant_id: nil,
          corrective_path: item.tab_path("item_setup"),
          corrective_label: "Review identifiers",
          source: :catalog
        )
      ]
    end

    def missing_catalog_thumbnail_warnings
      return [] if ThumbnailResolver.resolve(item:).source != :placeholder

      [
        build_warning(
          severity: :info,
          category: :data_quality,
          code: :missing_thumbnail,
          message: "No catalog or product thumbnail is on file.",
          variant_id: nil,
          corrective_path: item.tab_path("item_setup"),
          corrective_label: "Item setup",
          source: :catalog
        )
      ]
    end

    def build_warning(severity:, category:, code:, message:, variant_id:, source:, corrective_path: nil, corrective_label: nil)
      Warning.new(
        severity: severity,
        category: category,
        code: code,
        message: message,
        variant_id: variant_id,
        corrective_path: corrective_path,
        corrective_label: corrective_label,
        source: source
      )
    end

    def action_for(code, variant)
      case code
      when :missing_vendor_source, :missing_preferred_vendor, :missing_cost
        return nil if variant.blank?

        { label: "Assign vendor", path: Items::VendorSourcingPath.for(variant) }
      when :missing_identifier, :invalid_identifier
        { label: "Review identifiers", path: item&.tab_path("item_setup") }
      end
    end
  end
end
