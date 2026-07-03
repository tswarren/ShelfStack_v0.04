# frozen_string_literal: true

module DemandAllocations
  class ConvertInboundFromReceipt
    class ConversionError < StandardError; end

    def self.call!(receipt:, actor:)
      new(receipt:, actor:).call!
    end

    def initialize(receipt:, actor:)
      @receipt = receipt
      @actor = actor
    end

    def call!
      views = Receiving::ReceiptPostingMatchAdapter.call(receipt: receipt)
      if views.any?
        views.each { |view| convert_adapter_view!(view) }
      elsif receipt.po_backed?
        receipt.receipt_lines.each { |receipt_line| convert_receipt_line!(receipt_line) }
      end
    end

    private

    attr_reader :receipt, :actor

    def convert_adapter_view!(view)
      return if view.quantity_accepted.zero?
      return if view.purchase_order_line.blank?

      receipt_line = view.receipt_line
      return if already_converted?(receipt_line, view.purchase_order_line)

      remaining = view.quantity_accepted
      inbound_allocations_for(view.purchase_order_line).each do |inbound|
        break if remaining.zero?

        convert_qty = [ remaining, inbound.quantity_allocated ].min
        convert_allocation!(inbound, receipt_line:, convert_qty:, po_line: view.purchase_order_line)
        remaining -= convert_qty
      end
    end

    def convert_receipt_line!(receipt_line)
      return if receipt_line.quantity_accepted.zero?
      return if receipt_line.purchase_order_line.blank?
      return if already_converted?(receipt_line, receipt_line.purchase_order_line)

      remaining = receipt_line.quantity_accepted
      inbound_allocations_for(receipt_line.purchase_order_line).each do |inbound|
        break if remaining.zero?

        convert_qty = [ remaining, inbound.quantity_allocated ].min
        convert_allocation!(inbound, receipt_line:, convert_qty:, po_line: receipt_line.purchase_order_line)
        remaining -= convert_qty
      end
    end

    def already_converted?(receipt_line, purchase_order_line)
      DemandAllocation.where(conversion_receipt_line_id: receipt_line.id)
                      .where(allocation_kind: "on_hand")
                      .where(conversion_purchase_order_line_id: purchase_order_line.id)
                      .exists?
    end

    def inbound_allocations_for(purchase_order_line)
      DemandAllocation.active_allocations
                      .inbound_kind
                      .where(purchase_order_line_id: purchase_order_line.id)
                      .order(:allocated_at, :id)
    end

    def convert_allocation!(inbound, receipt_line:, convert_qty:, po_line:)
      DemandLine.transaction do
        demand_line, locked_inbound = MutationSupport.lock_demand_and_allocation!(
          demand_line_id: inbound.demand_line_id,
          allocation_id: inbound.id
        )
        raise ConversionError, "Allocation is not active inbound" unless locked_inbound.active? && locked_inbound.allocation_kind == "inbound_purchase_order"

        now = Time.current
        remainder = locked_inbound.quantity_allocated - convert_qty

        on_hand = DemandAllocation.create!(
          store: locked_inbound.store,
          demand_line: demand_line,
          product: locked_inbound.product,
          product_variant: locked_inbound.product_variant,
          allocation_kind: "on_hand",
          status: DemandAllocation::ACTIVE_STATUS,
          quantity_allocated: convert_qty,
          expires_at: locked_inbound.expires_at,
          allocated_by_user: actor,
          allocated_at: now,
          converted_from_allocation_id: locked_inbound.id,
          conversion_receipt_line_id: receipt_line.id,
          conversion_purchase_order_line_id: po_line.id,
          conversion_reason: "receipt_post",
          notes: locked_inbound.notes
        )

        if remainder.positive?
          DemandAllocation.create!(
            store: locked_inbound.store,
            demand_line: demand_line,
            product: locked_inbound.product,
            product_variant: locked_inbound.product_variant,
            purchase_order_line: po_line,
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
          status: "converted",
          converted_to_allocation_id: on_hand.id,
          conversion_receipt_line_id: receipt_line.id,
          conversion_purchase_order_line_id: po_line.id,
          converted_at: now,
          converted_by_user: actor,
          conversion_reason: "receipt_post"
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_allocation.converted_inbound_to_on_hand",
          auditable: on_hand,
          details: {
            "demand_number" => demand_line.demand_number,
            "quantity_allocated" => convert_qty,
            "receipt_line_id" => receipt_line.id,
            "source_allocation_id" => locked_inbound.id
          }
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_allocation.converted",
          auditable: locked_inbound,
          details: {
            "demand_number" => demand_line.demand_number,
            "converted_to_allocation_id" => on_hand.id,
            "receipt_line_id" => receipt_line.id
          }
        )

        MutationSupport.finalize_on_hand_mutation!(
          demand_line: demand_line,
          actor: actor,
          store: locked_inbound.store,
          variant: locked_inbound.product_variant
        )
      end
    end
  end
end
