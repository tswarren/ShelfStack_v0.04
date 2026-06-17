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
      end

      purchase_order
    end

    private

    attr_reader :purchase_order, :submitted_by_user

    def snapshot_line!(line)
      variant = line.product_variant
      sourcing = SourcingLookup.for(variant: variant, vendor: line.vendor)
      list_price = variant.product.list_price_cents
      discount_bps = sourcing.supplier_discount_bps

      line.update!(
        variant_sku_snapshot: variant.sku,
        variant_name_snapshot: variant.name,
        vendor_item_number_snapshot: sourcing.vendor_item_number,
        unit_list_price_cents: list_price,
        supplier_discount_bps: discount_bps,
        unit_cost_cents: VendorCostCalculator.unit_cost_cents(
          unit_list_price_cents: list_price,
          supplier_discount_bps: discount_bps
        ),
        returnability_status_snapshot: ReturnabilityResolver.resolve(variant: variant, vendor: line.vendor),
        product_variant_vendor: sourcing.product_variant_vendor
      )
    end
  end
end
