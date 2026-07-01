# frozen_string_literal: true

module DemandAllocations
  class InboundAvailability
    ELIGIBLE_PO_LINE_STATUSES = PurchaseOrderLine::STATUSES.reject { |s| %w[received cancelled closed_short closed].include?(s) }.freeze
    LEGACY_OPEN_ALLOCATION_STATUSES = %w[active partially_received].freeze

    def self.available_for(purchase_order_line:)
      new(purchase_order_line:).available_for
    end

    def initialize(purchase_order_line:)
      @purchase_order_line = purchase_order_line
    end

    def available_for
      open_qty = purchase_order_line.purchase_order.open_quantity_for_line(purchase_order_line)
      legacy_claimed = purchase_order_line.purchase_order_line_allocations
                                          .where(status: LEGACY_OPEN_ALLOCATION_STATUSES)
                                          .sum(:quantity_allocated)
      v0047_claimed = DemandAllocation.active_allocations
                                      .inbound_kind
                                      .where(purchase_order_line: purchase_order_line)
                                      .sum(:quantity_allocated)
      open_qty - legacy_claimed - v0047_claimed
    end

    def eligible?
      ELIGIBLE_PO_LINE_STATUSES.include?(purchase_order_line.status)
    end

    private

    attr_reader :purchase_order_line
  end
end
