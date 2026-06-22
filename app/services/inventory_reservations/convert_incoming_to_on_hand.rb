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
      raise ConvertError, "Receipt store mismatch" if receipt_line.receipt.store_id != reservation.store_id
      raise ConvertError, "Receipt line variant mismatch" if receipt_line.product_variant_id != reservation.product_variant_id

      converted = nil
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

        converted = if quantity < reservation.remaining_quantity
          split_partial_conversion!
        else
          convert_full!
          reservation
        end

        AuditEvents.record!(
          actor: converted_by_user,
          event_name: "inventory_reservation.converted_to_on_hand",
          auditable: converted,
          details: {
            "quantity" => quantity,
            "source_reservation_id" => reservation.id,
            "receipt_line_id" => receipt_line.id
          }
        )
      end
      converted
    end

    private

    attr_reader :reservation, :receipt_line, :quantity, :converted_by_user

    def convert_full!
      reservation.update!(
        reservation_type: "special_order_reserve",
        status: "ready",
        ready_at: Time.current,
        receipt_line: receipt_line
      )
    end

    def split_partial_conversion!
      on_hand = InventoryReservation.create!(
        store: reservation.store,
        customer: reservation.customer,
        customer_request_line: reservation.customer_request_line,
        special_order: reservation.special_order,
        product_variant: reservation.product_variant,
        purchase_order_line: reservation.purchase_order_line,
        reservation_type: "special_order_reserve",
        status: "ready",
        quantity_reserved: quantity,
        reserved_by_user: reservation.reserved_by_user,
        reserved_at: reservation.reserved_at,
        ready_at: Time.current,
        receipt_line: receipt_line,
        expires_at: reservation.expires_at,
        notes: reservation.notes
      )

      reservation.update!(quantity_reserved: reservation.quantity_reserved - quantity)
      on_hand
    end
  end
end
