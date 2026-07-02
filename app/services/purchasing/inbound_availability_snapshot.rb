# frozen_string_literal: true

module Purchasing
  class InboundAvailabilitySnapshot
    Snapshot = Data.define(
      :purchase_order_line,
      :effective_inbound_supply,
      :open_to_receive_quantity,
      :open_supply_before_allocation_claims,
      :legacy_claimed_quantity,
      :v0047_inbound_claimed_quantity,
      :open_for_inbound_allocation,
      :vendor_quantity_state,
      :vendor_quantities_recorded
    )

    def self.for(purchase_order_line:)
      new(purchase_order_line:).build
    end

    def initialize(purchase_order_line:)
      @purchase_order_line = purchase_order_line
    end

    def build
      summary = PoLineQuantitySummary.for(purchase_order_line)
      legacy_claimed = purchase_order_line.purchase_order_line_allocations
                                          .where(status: DemandAllocations::InboundAvailability::LEGACY_OPEN_ALLOCATION_STATUSES)
                                          .sum(:quantity_allocated)
      v0047_claimed = DemandAllocation.active_allocations
                                      .inbound_kind
                                      .where(purchase_order_line: purchase_order_line)
                                      .sum(:quantity_allocated)

      Snapshot.new(
        purchase_order_line: purchase_order_line,
        effective_inbound_supply: summary.effective_inbound_supply,
        open_to_receive_quantity: summary.open_to_receive_quantity,
        open_supply_before_allocation_claims: summary.open_supply_before_allocation_claims,
        legacy_claimed_quantity: legacy_claimed,
        v0047_inbound_claimed_quantity: v0047_claimed,
        open_for_inbound_allocation: summary.open_supply_before_allocation_claims - legacy_claimed - v0047_claimed,
        vendor_quantity_state: purchase_order_line.vendor_quantity_state,
        vendor_quantities_recorded: summary.vendor_quantities_recorded?
      )
    end

    private

    attr_reader :purchase_order_line
  end
end
