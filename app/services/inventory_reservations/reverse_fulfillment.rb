# frozen_string_literal: true

module InventoryReservations
  class ReverseFulfillment
    class ReverseError < StandardError; end

    def self.call!(reservation:, reversed_by_user:, quantity:)
      new(reservation:, reversed_by_user:, quantity:).call!
    end

    def initialize(reservation:, reversed_by_user:, quantity:)
      @reservation = reservation
      @reversed_by_user = reversed_by_user
      @quantity = quantity
    end

    def call!
      raise ReverseError, "Quantity must be positive" unless quantity.positive?
      raise ReverseError, "Cannot reverse more than fulfilled" if quantity > reservation.quantity_fulfilled

      InventoryBalance.transaction do
        balance = InventoryBalance.lock.find_by!(store: reservation.store, product_variant: reservation.product_variant)
        balance.quantity_reserved += quantity
        balance.quantity_available = balance.quantity_on_hand - balance.quantity_reserved
        balance.save!

        reservation.quantity_fulfilled -= quantity
        reservation.status = "ready"
        reservation.fulfilled_at = nil
        reservation.pos_transaction_line = nil
        reservation.save!

        if reservation.special_order.present?
          so = reservation.special_order
          quantity_completed = [ so.quantity_completed - quantity, 0 ].max
          fully_completed = quantity_completed + so.quantity_cancelled >= so.quantity_committed
          so.update!(
            status: fully_completed ? "completed" : "ready_for_pickup",
            quantity_completed: quantity_completed,
            quantity_ready: so.quantity_ready + quantity,
            completed_at: fully_completed ? so.completed_at || Time.current : nil
          )
        end

        if reservation.customer_request_line.present?
          line = reservation.customer_request_line
          filled_quantity = [ line.filled_quantity - quantity, 0 ].max
          line.update!(
            status: fulfillment_status_for(line, filled_quantity),
            filled_quantity: filled_quantity
          )
          line.customer_request.refresh_status_from_lines!
        end

        AuditEvents.record!(
          actor: reversed_by_user,
          event_name: "inventory_reservation.fulfillment_reversed",
          auditable: reservation,
          details: { "quantity" => quantity }
        )
      end
      reservation
    end

    private

    attr_reader :reservation, :reversed_by_user, :quantity

    def fulfillment_status_for(request_line, filled_quantity)
      if filled_quantity + request_line.cancelled_quantity >= request_line.requested_quantity
        "completed"
      elsif filled_quantity.positive?
        "partially_filled"
      else
        "ready_for_pickup"
      end
    end
  end
end
