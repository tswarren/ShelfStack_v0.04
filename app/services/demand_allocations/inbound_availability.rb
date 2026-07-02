# frozen_string_literal: true

module DemandAllocations
  class InboundAvailability
    ELIGIBLE_PO_LINE_STATUSES = PurchaseOrderLine::STATUSES.reject { |s| %w[received cancelled closed_short closed].include?(s) }.freeze
    def self.available_for(purchase_order_line:)
      new(purchase_order_line:).available_for
    end

    def initialize(purchase_order_line:)
      @purchase_order_line = purchase_order_line
    end

    def available_for
      [ raw_open_for_inbound_allocation, 0 ].max
    end

    def raw_open_for_inbound_allocation
      summary = Purchasing::PoLineQuantitySummary.for(purchase_order_line)
      summary.open_supply_before_allocation_claims - v0047_inbound_claimed_quantity
    end

    def overclaimed_quantity
      [ -raw_open_for_inbound_allocation, 0 ].max
    end

    def v0047_inbound_claimed_quantity
      DemandAllocation.active_allocations
                      .inbound_kind
                      .where(purchase_order_line: purchase_order_line)
                      .sum(:quantity_allocated)
    end

    def eligible?
      purchase_order = purchase_order_line.purchase_order
      PurchaseOrder::RECEIVABLE_PO_STATUSES.include?(purchase_order.status) &&
        ELIGIBLE_PO_LINE_STATUSES.include?(purchase_order_line.status)
    end

    private

    attr_reader :purchase_order_line
  end
end
