# frozen_string_literal: true

module Pos
  class CompleteReservationFulfillment
    def self.call!(transaction:, fulfilled_by_user:)
      new(transaction:, fulfilled_by_user:).call!
    end

    def initialize(transaction:, fulfilled_by_user:)
      @transaction = transaction
      @fulfilled_by_user = fulfilled_by_user
    end

    def call!
      transaction.pos_transaction_lines.each do |line|
        next if line.inventory_reservation_id.blank?

        reservation = line.inventory_reservation
        InventoryReservations::FulfillAtPos.call!(
          reservation: reservation,
          pos_transaction_line: line,
          quantity: line.quantity.abs,
          fulfilled_by_user: fulfilled_by_user
        )

        if reservation.special_order.present?
          so = reservation.special_order
          quantity = line.quantity.abs
          quantity_completed = so.quantity_completed + quantity
          fully_completed = quantity_completed + so.quantity_cancelled >= so.quantity_committed
          quantity_ready = [ so.quantity_ready - quantity, 0 ].max
          so.update!(
            status: fully_completed ? "completed" : "ready_for_pickup",
            quantity_completed: quantity_completed,
            quantity_ready: quantity_ready,
            completed_at: fully_completed ? Time.current : nil
          )
        end

        if reservation.customer_request_line.present?
          req_line = reservation.customer_request_line
          quantity = line.quantity.abs
          filled_quantity = req_line.filled_quantity + quantity
          req_line.update!(
            status: fulfillment_status_for(req_line, filled_quantity),
            filled_quantity: filled_quantity
          )
          req_line.customer_request.refresh_status_from_lines!(actor: fulfilled_by_user, source: req_line)
        end
      end
    end

    private

    attr_reader :transaction, :fulfilled_by_user

    def fulfillment_status_for(request_line, filled_quantity)
      if filled_quantity + request_line.cancelled_quantity >= request_line.requested_quantity
        "completed"
      else
        "partially_filled"
      end
    end
  end
end
