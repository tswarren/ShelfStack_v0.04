# frozen_string_literal: true

module Sourcing
  module VendorSourceSnapshot
    Snapshot = Data.define(
      :vendor_name_snapshot,
      :vendor_item_number_snapshot,
      :source_level_snapshot,
      :source_record_type,
      :source_record_id,
      :vendor_priority_snapshot,
      :estimated_unit_cost_cents_snapshot,
      :returnability_snapshot,
      :product_variant_vendor_id,
      :product_vendor_id
    )

    module_function

    def build(variant:, vendor:, suggestion:, manual_override: false)
      pvv = suggestion&.product_variant_vendor
      pv = suggestion&.product_vendor
      list_price = variant.selling_price_cents || variant.product&.list_price_cents
      discount_bps = pvv&.supplier_discount_bps || pv&.supplier_discount_bps
      unit_cost = Purchasing::VendorCostCalculator.unit_cost_cents(
        unit_list_price_cents: list_price,
        supplier_discount_bps: discount_bps
      )
      returnability = Purchasing::ReturnabilityResolver.resolve(variant: variant, vendor: vendor)

      source_level = map_source_level(suggestion&.source, manual_override: manual_override)
      source_record = pvv || pv

      Snapshot.new(
        vendor_name_snapshot: vendor.name,
        vendor_item_number_snapshot: pvv&.vendor_item_number || pv&.vendor_item_number,
        source_level_snapshot: source_level,
        source_record_type: source_record&.class&.name,
        source_record_id: source_record&.id,
        vendor_priority_snapshot: nil,
        estimated_unit_cost_cents_snapshot: unit_cost,
        returnability_snapshot: returnability,
        product_variant_vendor_id: pvv&.id,
        product_vendor_id: pv&.id
      )
    end

    def map_source_level(source, manual_override:)
      return "manual" if manual_override

      case source.to_s
      when "variant_preferred", "variant_vendor_source", "variant_vendor_fallback"
        "variant_vendor"
      when "product_preferred", "product_vendor_source", "product_vendor_fallback"
        "product_vendor"
      when "variant_preferred"
        "preferred"
      else
        source.presence || "manual"
      end
    end
  end
end
