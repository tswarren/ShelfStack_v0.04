# frozen_string_literal: true

module Receiving
  class AllocateCustomerDemandFromReceipt
    class AllocateError < StandardError; end

    def self.call!(receipt:, posted_by_user:)
      new(receipt:, posted_by_user:).call!
    end

    def initialize(receipt:, posted_by_user:)
      @receipt = receipt
      @posted_by_user = posted_by_user
    end

    def call!
      receipt.receipt_lines.each do |receipt_line|
        next if receipt_line.quantity_accepted.zero?

        allocate_po_backed_lines!(receipt_line)
        flag_notify_lines!(receipt_line)
      end
    end

    private

    attr_reader :receipt, :posted_by_user

    def allocate_po_backed_lines!(receipt_line)
      po_line = receipt_line.purchase_order_line
      return if po_line.blank?

      remaining = receipt_line.quantity_accepted
      po_line.purchase_order_line_allocations.open_allocations.order(:created_at).each do |allocation|
        break if remaining.zero?

        alloc_qty = [ allocation.quantity_allocated - allocation.quantity_received, remaining ].min
        next if alloc_qty.zero?

        ReceiptLineAllocation.create!(
          receipt_line: receipt_line,
          purchase_order_line_allocation: allocation,
          customer_request_line: allocation.customer_request_line,
          special_order: allocation.special_order,
          quantity_allocated: alloc_qty
        )

        allocation.update!(
          quantity_received: allocation.quantity_received + alloc_qty,
          status: allocation.quantity_received + alloc_qty >= allocation.quantity_allocated ? "received" : "partially_received"
        )

        incoming = InventoryReservation.active_incoming.find_by(
          purchase_order_line: po_line,
          special_order: allocation.special_order
        )
        if incoming.present?
          InventoryReservations::ConvertIncomingToOnHand.call!(
            reservation: incoming,
            receipt_line: receipt_line,
            quantity: alloc_qty,
            converted_by_user: posted_by_user
          )
        end

        special_order = allocation.special_order
        special_order.update!(
          quantity_received: special_order.quantity_received + alloc_qty,
          quantity_ready: special_order.quantity_ready + alloc_qty,
          status: "ready_for_pickup",
          ready_at: Time.current
        )

        request_line = allocation.customer_request_line
        if request_line.present?
          request_line.update!(status: "ready_for_pickup")
          request_line.customer_request.refresh_status_from_lines!
        end

        AuditEvents.record!(
          actor: posted_by_user,
          event_name: "receipt_line_allocation.created",
          auditable: receipt_line,
          details: { "quantity_allocated" => alloc_qty, "special_order_id" => special_order.id }
        )

        remaining -= alloc_qty
      end
    end

    def flag_notify_lines!(receipt_line)
      variant = receipt_line.product_variant
      return if variant.blank?

      CustomerRequestLine.open_lines
                         .where(request_type: "notify", product_variant: variant, status: "matched")
                         .joins(:customer_request)
                         .where(customer_requests: { store_id: receipt.store_id })
                         .find_each do |line|
        # Notify queue only — no auto-hold per spec revision
        line.update!(status: "ready_for_pickup") if line.status == "matched"
        line.customer_request.refresh_status_from_lines!
      end
    end
  end
end
