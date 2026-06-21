# frozen_string_literal: true

module InventoryReservations
  class ConvertIncomingToOnHand
    class ConvertError < StandardError; end

    def self.call!(reservation:, receipt_line:, quantity:, converted_by_user:)
      new(reservation:, receipt_line:, quantity:, converted_by_user:).call!
    end

    def initialize(reservation:, receipt_line:, quantity:, converted_by_user:)
      @reservation = reservation
      @receipt_line = receipt_line
      @quantity = quantity
      @converted_by_user = converted_by_user
    end

    def call!
      raise ConvertError, "Reservation must be incoming_reserve" unless reservation.reservation_type == "incoming_reserve"
      raise ConvertError, "Quantity exceeds remaining" if quantity > reservation.remaining_quantity

      InventoryBalance.transaction do
        balance = InventoryBalance.lock.find_or_initialize_by(
          store: reservation.store,
          product_variant: reservation.product_variant
        )
        balance.quantity_on_hand ||= 0
        balance.quantity_reserved ||= 0
        balance.quantity_reserved += quantity
        balance.quantity_available = balance.quantity_on_hand - balance.quantity_reserved
        balance.save!

        reservation.reservation_type = "special_order_reserve"
        reservation.status = "ready"
        reservation.ready_at = Time.current
        reservation.receipt_line = receipt_line
        reservation.save!
      end
      reservation
    end

    private

    attr_reader :reservation, :receipt_line, :quantity, :converted_by_user
  end
end
