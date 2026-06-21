# frozen_string_literal: true

module InventoryReservations
  class FulfillAtPos
    class FulfillError < StandardError; end

    def self.call!(reservation:, pos_transaction_line:, quantity:, fulfilled_by_user:)
      new(reservation:, pos_transaction_line:, quantity:, fulfilled_by_user:).call!
    end

    def initialize(reservation:, pos_transaction_line:, quantity:, fulfilled_by_user:)
      @reservation = reservation
      @pos_transaction_line = pos_transaction_line
      @quantity = quantity
      @fulfilled_by_user = fulfilled_by_user
    end

    def call!
      raise FulfillError, "Reservation must be active or ready" unless %w[active ready].include?(reservation.status)
      raise FulfillError, "Quantity exceeds remaining" if quantity > reservation.remaining_quantity

      InventoryBalance.transaction do
        if reservation.counts_toward_on_hand_reserved?
          balance = InventoryBalance.lock.find_by!(store: reservation.store, product_variant: reservation.product_variant)
          balance.quantity_reserved -= quantity
          balance.quantity_available = balance.quantity_on_hand - balance.quantity_reserved
          balance.save!
        end

        reservation.quantity_fulfilled += quantity
        reservation.pos_transaction_line = pos_transaction_line
        reservation.status = reservation.remaining_quantity.zero? ? "fulfilled" : reservation.status
        reservation.fulfilled_at = Time.current if reservation.remaining_quantity.zero?
        reservation.save!

        AuditEvents.record!(
          actor: fulfilled_by_user,
          event_name: "inventory_reservation.fulfilled",
          auditable: reservation,
          details: { "quantity" => quantity, "pos_transaction_line_id" => pos_transaction_line.id }
        )
      end
      reservation
    end

    private

    attr_reader :reservation, :pos_transaction_line, :quantity, :fulfilled_by_user
  end
end
