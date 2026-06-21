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
          so.update!(
            status: "completed",
            quantity_completed: so.quantity_completed + line.quantity.abs,
            completed_at: Time.current
          )
        end

        if reservation.customer_request_line.present?
          req_line = reservation.customer_request_line
          req_line.update!(
            status: "completed",
            filled_quantity: req_line.filled_quantity + line.quantity.abs
          )
          req_line.customer_request.refresh_status_from_lines!
        end
      end
    end

    private

    attr_reader :transaction, :fulfilled_by_user
  end
end
