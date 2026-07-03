# frozen_string_literal: true

module DemandAllocations
  class EligibleInboundLines
    Option = Data.define(
      :purchase_order_line,
      :purchase_order,
      :vendor,
      :quantity_ordered,
      :quantity_received,
      :open_to_receive,
      :already_allocated,
      :available_to_allocate
    )

    def self.for(demand_line:, store:)
      new(demand_line:, store:).call
    end

    def initialize(demand_line:, store:)
      @demand_line = demand_line
      @store = store
    end

    def call
      variant = demand_line.product_variant
      return [] if variant.blank?

      lines = PurchaseOrderLine.joins(:purchase_order)
                               .includes(:purchase_order, :vendor)
                               .where(purchase_orders: { store_id: store.id })
                               .where(product_variant_id: variant.id)
                               .merge(PurchaseOrder.submitted_records)
                               .where(status: InboundAvailability::ELIGIBLE_PO_LINE_STATUSES)
                               .order("purchase_orders.created_at DESC")

      lines.filter_map do |line|
        inbound = InboundAvailability.new(purchase_order_line: line)
        next unless inbound.eligible?

        available = inbound.available_for
        next if available <= 0

        summary = Purchasing::PoLineQuantitySummary.for(line)
        Option.new(
          purchase_order_line: line,
          purchase_order: line.purchase_order,
          vendor: line.vendor,
          quantity_ordered: line.quantity_ordered,
          quantity_received: line.quantity_received,
          open_to_receive: summary.open_to_receive_quantity,
          already_allocated: inbound.v0047_inbound_claimed_quantity,
          available_to_allocate: available
        )
      end
    end

    private

    attr_reader :demand_line, :store
  end
end
