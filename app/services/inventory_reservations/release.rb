# frozen_string_literal: true

module InventoryReservations
  class Release
    class ReleaseError < StandardError; end

    def self.call!(reservation:, released_by_user:, release_reason:, quantity: nil)
      new(reservation:, released_by_user:, release_reason:, quantity:).call!
    end

    def initialize(reservation:, released_by_user:, release_reason:, quantity: nil)
      @reservation = reservation
      @released_by_user = released_by_user
      @release_reason = release_reason
      @quantity = quantity
    end

    def call!
      raise ReleaseError, "Invalid release reason" unless InventoryReservation::RELEASE_REASONS.include?(release_reason)

      qty = quantity || reservation.remaining_quantity
      raise ReleaseError, "Quantity must be positive" unless qty.positive?
      raise ReleaseError, "Cannot release more than remaining" if qty > reservation.remaining_quantity

      InventoryBalance.transaction do
        if reservation.counts_toward_on_hand_reserved?
          balance = InventoryBalance.lock.find_by!(store: reservation.store, product_variant: reservation.product_variant)
          balance.quantity_reserved -= qty
          balance.quantity_available = balance.quantity_on_hand - balance.quantity_reserved
          balance.save!
        end

        reservation.quantity_released += qty
        reservation.status = reservation.remaining_quantity.zero? ? "released" : reservation.status
        reservation.released_at = Time.current
        reservation.release_reason = release_reason
        reservation.save!

        AuditEvents.record!(
          actor: released_by_user,
          event_name: "inventory_reservation.released",
          auditable: reservation,
          details: { "quantity" => qty, "release_reason" => release_reason }
        )
      end
      reservation
    end

    private

    attr_reader :reservation, :released_by_user, :release_reason, :quantity
  end
end
