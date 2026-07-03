# frozen_string_literal: true

module Purchasing
  class SubmitPurchaseOrder
    class SubmitError < StandardError; end

    def self.call(purchase_order:, submitted_by_user:)
      new(purchase_order:, submitted_by_user:).call
    end

    def initialize(purchase_order:, submitted_by_user:)
      @purchase_order = purchase_order
      @submitted_by_user = submitted_by_user
    end

    def call
      raise SubmitError, "Purchase order is not a draft" unless purchase_order.draft?
      raise SubmitError, "Purchase order has no lines" if purchase_order.purchase_order_lines.empty?

      validate_submit_eligibility!

      PurchaseOrder.transaction do
        purchase_order.purchase_order_lines.each do |line|
          snapshot_line!(line)
        end

        purchase_order.update!(
          status: "submitted",
          submitted_at: Time.current,
          submitted_by_user: submitted_by_user
        )

        AuditEvents.record!(
          actor: submitted_by_user,
          event_name: "purchase_order.submitted",
          auditable: purchase_order,
          details: { "line_count" => purchase_order.purchase_order_lines.size }
        )

        ConvertDemandCoveragePlansToInbound.call!(purchase_order: purchase_order, actor: submitted_by_user)
      end

      purchase_order
    end

    private

    attr_reader :purchase_order, :submitted_by_user

    def validate_submit_eligibility!
      purchase_order.purchase_order_lines.each do |line|
        prepare_line_economics!(line)

        if line.unit_cost_cents.blank?
          raise SubmitError,
            "Line #{line.line_number} cannot be submitted: Expected unit cost could not be determined."
        end

        result = OrderEligibilityResolver.call(
          product_variant: line.product_variant,
          vendor: line.vendor,
          context: :purchase_order_submit
        )
        next unless result.submit_blocked?

        messages = result.blocking_reasons.map(&:message).join("; ")
        raise SubmitError, "Line #{line.line_number} cannot be submitted: #{messages}"
      end
    end

    def prepare_line_economics!(line)
      LineEconomicsSync.apply!(line, apply_defaults: :always)
    end

    def snapshot_line!(line)
      prepare_line_economics!(line)
      sourcing = SourcingLookup.for(variant: line.product_variant, vendor: line.vendor)

      line.update!(
        variant_sku_snapshot: line.product_variant.sku,
        variant_name_snapshot: line.product_variant.name,
        vendor_item_number_snapshot: sourcing.vendor_item_number,
        unit_list_price_cents: line.unit_list_price_cents,
        supplier_discount_bps: line.supplier_discount_bps,
        unit_cost_cents: line.unit_cost_cents,
        expected_retail_price_cents: line.expected_retail_price_cents,
        expected_line_cost_cents: line.expected_line_cost_cents,
        expected_line_retail_cents: line.expected_line_retail_cents,
        expected_margin_cents: line.expected_margin_cents,
        expected_margin_bps: line.expected_margin_bps,
        cost_source: line.cost_source,
        price_source: line.price_source,
        manual_cost_override: line.manual_cost_override,
        manual_price_override: line.manual_price_override,
        returnability_status_snapshot: ReturnabilityResolver.resolve(variant: line.product_variant, vendor: line.vendor),
        product_variant_vendor: line.product_variant_vendor,
        source_snapshot: {
          "vendor_item_number" => sourcing.vendor_item_number,
          "supplier_discount_bps" => sourcing.supplier_discount_bps,
          "unit_list_price_cents" => line.unit_list_price_cents,
          "unit_cost_cents" => line.unit_cost_cents,
          "expected_retail_price_cents" => line.expected_retail_price_cents
        }
      )
    end
  end
end
