# frozen_string_literal: true

module DemandAllocations
  class ReleaseUncoveredInbound
    class ReleaseError < StandardError; end

    RELEASE_REASONS = %w[receipt_short po_closed_short vendor_canceled not_replaceable explicit_release].freeze

    def self.call!(purchase_order_line:, actor:, release_reason:)
      new(purchase_order_line:, actor:, release_reason:).call!
    end

    def initialize(purchase_order_line:, actor:, release_reason:)
      @purchase_order_line = purchase_order_line
      @actor = actor
      @release_reason = release_reason.to_s
    end

    def call!
      raise ReleaseError, "Invalid release reason" unless RELEASE_REASONS.include?(release_reason)

      uncovered = uncovered_quantity
      return if uncovered <= 0

      release_quantity_reverse_fifo!(uncovered)
    end

    private

    attr_reader :purchase_order_line, :actor, :release_reason

    def uncovered_quantity
      supply = Purchasing::PoLineQuantitySummary.for(purchase_order_line).open_supply_before_allocation_claims
      claimed = DemandAllocation.active_allocations
                                .inbound_kind
                                .where(purchase_order_line: purchase_order_line)
                                .sum(:quantity_allocated)
      claimed - supply
    end

    def release_quantity_reverse_fifo!(quantity_to_release)
      remaining = quantity_to_release
      inbound_allocations_reverse_fifo.each do |allocation|
        break if remaining.zero?

        release_qty = [ remaining, allocation.quantity_allocated ].min
        if release_qty >= allocation.quantity_allocated
          Release.call!(allocation: allocation, actor: actor, release_reason: release_reason)
        else
          split_and_release_partial!(allocation, release_qty:)
        end
        remaining -= release_qty
      end
    end

    def inbound_allocations_reverse_fifo
      DemandAllocation.active_allocations
                      .inbound_kind
                      .where(purchase_order_line: purchase_order_line)
                      .order(allocated_at: :desc, id: :desc)
    end

    def split_and_release_partial!(allocation, release_qty:)
      DemandLine.transaction do
        demand_line, locked_inbound = MutationSupport.lock_demand_and_allocation!(
          demand_line_id: allocation.demand_line_id,
          allocation_id: allocation.id
        )
        remainder = locked_inbound.quantity_allocated - release_qty
        now = Time.current

        if remainder.positive?
          DemandAllocation.create!(
            store: locked_inbound.store,
            demand_line: demand_line,
            product: locked_inbound.product,
            product_variant: locked_inbound.product_variant,
            purchase_order_line: purchase_order_line,
            allocation_kind: "inbound_purchase_order",
            status: DemandAllocation::ACTIVE_STATUS,
            quantity_allocated: remainder,
            expires_at: locked_inbound.expires_at,
            allocated_by_user: actor,
            allocated_at: now,
            converted_from_allocation_id: locked_inbound.id,
            sourcing_attempt_id: locked_inbound.sourcing_attempt_id,
            vendor_response_id: locked_inbound.vendor_response_id,
            notes: locked_inbound.notes
          )
        end

        locked_inbound.update!(
          status: "released",
          released_by_user: actor,
          released_at: now,
          release_reason: release_reason
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_allocation.released",
          auditable: locked_inbound,
          details: {
            "demand_number" => demand_line.demand_number,
            "release_reason" => release_reason,
            "quantity_released" => release_qty
          }
        )

        MutationSupport.finalize_inbound_mutation!(demand_line: demand_line, actor: actor)
      end
    end
  end
end
