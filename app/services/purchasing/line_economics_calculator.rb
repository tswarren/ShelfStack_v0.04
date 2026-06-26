# frozen_string_literal: true

module Purchasing
  class LineEconomicsCalculator
    CHANGED_FIELDS = %w[
      unit_list_price_cents
      supplier_discount_bps
      unit_cost_cents
      expected_retail_price_cents
      quantity_ordered
    ].freeze

    Result = Data.define(
      :unit_list_price_cents,
      :supplier_discount_bps,
      :unit_cost_cents,
      :expected_retail_price_cents,
      :expected_line_cost_cents,
      :expected_line_retail_cents,
      :expected_margin_cents,
      :expected_margin_bps,
      :cost_source,
      :price_source,
      :manual_cost_override,
      :manual_price_override
    )

    def self.call(line:, changed_field: nil, recalculate_from_vendor: false)
      new(line:, changed_field:, recalculate_from_vendor:).call
    end

    def self.apply!(line, **kwargs)
      result = call(line:, **kwargs)
      line.assign_attributes(result.to_h)
      line
    end

    def initialize(line:, changed_field: nil, recalculate_from_vendor: false)
      @line = line
      @changed_field = changed_field&.to_s
      @recalculate_from_vendor = recalculate_from_vendor
    end

    def call
      attrs = base_attributes
      apply_vendor_recalc!(attrs) if recalculate_from_vendor
      apply_field_change!(attrs) if changed_field.present?
      sync_cost_from_pricing!(attrs) unless attrs[:manual_cost_override] || changed_field == "unit_cost_cents"
      apply_totals!(attrs)
      Result.new(**attrs)
    end

    private

    attr_reader :line, :changed_field, :recalculate_from_vendor

    def base_attributes
      {
        unit_list_price_cents: line.unit_list_price_cents,
        supplier_discount_bps: line.supplier_discount_bps,
        unit_cost_cents: line.unit_cost_cents,
        expected_retail_price_cents: line.expected_retail_price_cents || line.product_variant&.selling_price_cents,
        expected_line_cost_cents: line.expected_line_cost_cents,
        expected_line_retail_cents: line.expected_line_retail_cents,
        expected_margin_cents: line.expected_margin_cents,
        expected_margin_bps: line.expected_margin_bps,
        cost_source: line.cost_source.presence || "unknown",
        price_source: line.price_source.presence || "unknown",
        manual_cost_override: line.manual_cost_override == true,
        manual_price_override: line.manual_price_override == true
      }
    end

    def apply_vendor_recalc!(attrs)
      defaults = LinePriceDefaults.resolve(
        variant: line.product_variant,
        vendor: line.vendor
      )
      attrs[:unit_list_price_cents] = defaults.unit_list_price_cents
      attrs[:supplier_discount_bps] = defaults.supplier_discount_bps
      attrs[:unit_cost_cents] = defaults.unit_cost_cents
      attrs[:cost_source] = "vendor_source"
      attrs[:manual_cost_override] = false
      attrs[:manual_price_override] = false
      if attrs[:expected_retail_price_cents].blank?
        attrs[:expected_retail_price_cents] = line.product_variant&.selling_price_cents
        attrs[:price_source] = "variant"
      end
    end

    def apply_field_change!(attrs)
      return if changed_field.blank?

      case changed_field
      when "unit_list_price_cents", "supplier_discount_bps"
        recalc_cost_from_list!(attrs) unless attrs[:manual_cost_override]
        attrs[:cost_source] = "manual" if changed_field == "unit_cost_cents"
      when "unit_cost_cents"
        attrs[:manual_cost_override] = true
        attrs[:cost_source] = "manual"
        recalc_discount_from_cost!(attrs)
      when "expected_retail_price_cents"
        attrs[:manual_price_override] = true
        attrs[:price_source] = "manual"
      when "quantity_ordered"
        # totals only
      end
    end

    def recalc_cost_from_list!(attrs)
      attrs[:unit_cost_cents] = VendorCostCalculator.unit_cost_cents(
        unit_list_price_cents: attrs[:unit_list_price_cents],
        supplier_discount_bps: attrs[:supplier_discount_bps]
      )
      attrs[:cost_source] = "vendor_source" unless attrs[:manual_cost_override]
    end

    def recalc_discount_from_cost!(attrs)
      attrs[:supplier_discount_bps] = VendorCostCalculator.supplier_discount_bps(
        unit_list_price_cents: attrs[:unit_list_price_cents],
        unit_cost_cents: attrs[:unit_cost_cents]
      )
    end

    def sync_cost_from_pricing!(attrs)
      return if attrs[:unit_list_price_cents].blank?

      attrs[:unit_cost_cents] = VendorCostCalculator.unit_cost_cents(
        unit_list_price_cents: attrs[:unit_list_price_cents],
        supplier_discount_bps: attrs[:supplier_discount_bps]
      )
      attrs[:cost_source] = "vendor_source" unless attrs[:manual_cost_override]
    end

    def apply_totals!(attrs)
      qty = line.quantity_ordered.to_i
      cost = attrs[:unit_cost_cents]
      retail = attrs[:expected_retail_price_cents]
      attrs[:expected_line_cost_cents] = cost.present? ? cost * qty : nil
      attrs[:expected_line_retail_cents] = retail.present? ? retail * qty : nil
      if attrs[:expected_line_retail_cents].present? && attrs[:expected_line_cost_cents].present?
        margin = attrs[:expected_line_retail_cents] - attrs[:expected_line_cost_cents]
        attrs[:expected_margin_cents] = margin
        attrs[:expected_margin_bps] = if attrs[:expected_line_retail_cents].positive?
          ((margin.to_f / attrs[:expected_line_retail_cents]) * 10_000).round
        end
      else
        attrs[:expected_margin_cents] = nil
        attrs[:expected_margin_bps] = nil
      end
    end
  end
end
