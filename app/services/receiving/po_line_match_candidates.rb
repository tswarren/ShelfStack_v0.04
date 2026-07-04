# frozen_string_literal: true

module Receiving
  class PoLineMatchCandidates
    Candidate = Data.define(
      :purchase_order_line,
      :purchase_order,
      :open_to_receive_quantity,
      :customer_planned_quantity,
      :shelf_planned_quantity,
      :sort_priority
    )

    def self.call(receipt_line:, purchase_order_id: nil)
      new(receipt_line:, purchase_order_id:).call
    end

    def initialize(receipt_line:, purchase_order_id: nil)
      @receipt_line = receipt_line
      @purchase_order_id = purchase_order_id
    end

    def call
      variant = receipt_line.product_variant
      store = receipt_line.receipt.store
      vendor = receipt_line.receipt.vendor
      scope = PurchaseOrderLine.joins(:purchase_order)
                       .where(purchase_orders: { store_id: store.id, vendor_id: vendor.id, status: PurchaseOrder::RECEIVABLE_PO_STATUSES })

      if filter_purchase_order_id.present?
        scope = scope.where(purchase_orders: { id: filter_purchase_order_id })
      end

      scope
                       .where(product_variant_id: variant.id, status: PurchaseOrder::OPEN_FOR_RECEIVE_LINE_STATUSES)
                       .includes(:purchase_order, :purchase_order_line_demand_plans)
                       .filter_map do |po_line|
        open_qty = Purchasing::PoLineQuantitySummary.for(po_line).open_to_receive_quantity
        next if open_qty <= 0

        plans = po_line.purchase_order_line_demand_plans.active_plans
        customer_qty = plans.select { |p| p.coverage_kind == "customer_fulfillment" }.sum(&:quantity_planned)
        shelf_qty = plans.select { |p| p.coverage_kind == "shelf_replenishment" }.sum(&:quantity_planned)
        priority = customer_qty.positive? ? 0 : 1

        Candidate.new(
          purchase_order_line: po_line,
          purchase_order: po_line.purchase_order,
          open_to_receive_quantity: open_qty,
          customer_planned_quantity: customer_qty,
          shelf_planned_quantity: shelf_qty,
          sort_priority: priority
        )
      end.sort_by { |c| [ c.sort_priority, c.purchase_order.submitted_at || Time.at(0), c.purchase_order_line.line_number ] }
    end

    private

    attr_reader :receipt_line, :purchase_order_id

    def filter_purchase_order_id
      purchase_order_id.presence || receipt_line.receipt.match_filter_purchase_order_id
    end
  end
end
