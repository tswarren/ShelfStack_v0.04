# frozen_string_literal: true

module InventoryReservations
  class Expire
    def self.call!(actor: nil)
      new(actor:).call!
    end

    def initialize(actor: nil)
      @actor = actor
    end

    def call!
      expired_count = 0
      InventoryReservation.active_on_hand
                          .where("expires_at IS NOT NULL AND expires_at <= ?", Time.current)
                          .find_each do |reservation|
        Release.call!(
          reservation: reservation,
          released_by_user: actor || reservation.reserved_by_user,
          release_reason: "expired",
          quantity: reservation.remaining_quantity
        )
        reservation.update!(status: "expired")
        AuditEvents.record!(
          actor: actor || reservation.reserved_by_user,
          event_name: "inventory_reservation.expired",
          auditable: reservation,
          details: {}
        )
        expired_count += 1
      end
      expired_count
    end

    private

    attr_reader :actor
  end
end
