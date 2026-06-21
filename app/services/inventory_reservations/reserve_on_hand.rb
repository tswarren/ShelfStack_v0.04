# frozen_string_literal: true

module InventoryReservations
  class ReserveOnHand
    class ReserveError < StandardError; end

    DEFAULT_EXPIRY_DAYS = 14

    def self.call!(store:, variant:, quantity:, reserved_by_user:, customer: nil, customer_request_line: nil,
                   special_order: nil, expires_at: nil, override_authorized_by_user: nil, override_reason: nil)
      new(
        store:, variant:, quantity:, reserved_by_user:, customer:, customer_request_line:, special_order:,
        expires_at:, override_authorized_by_user:, override_reason:
      ).call!
    end

    def initialize(store:, variant:, quantity:, reserved_by_user:, customer: nil, customer_request_line: nil,
                   special_order: nil, expires_at: nil, override_authorized_by_user: nil, override_reason: nil)
      @store = store
      @variant = variant
      @quantity = quantity
      @reserved_by_user = reserved_by_user
      @customer = customer
      @customer_request_line = customer_request_line
      @special_order = special_order
      @expires_at = expires_at
      @override_authorized_by_user = override_authorized_by_user
      @override_reason = override_reason
    end

    def call!
      raise ReserveError, "Quantity must be positive" unless quantity.positive?

      reservation = nil
      InventoryBalance.transaction do
        balance = InventoryBalance.lock.find_or_initialize_by(store: store, product_variant: variant)
        balance.quantity_on_hand ||= 0
        balance.quantity_reserved ||= 0
        available = balance.quantity_on_hand - balance.quantity_reserved

        over_reserved = false
        if quantity > available
          if override_authorized_by_user.blank?
            raise ReserveError, "Insufficient available quantity (#{available})"
          end

          over_reserved = true
        end

        reserved_at = Time.current
        reservation = InventoryReservation.create!(
          store: store,
          customer: customer,
          customer_request_line: customer_request_line,
          special_order: special_order,
          product_variant: variant,
          reservation_type: special_order.present? ? "special_order_reserve" : "on_hand_hold",
          status: "active",
          quantity_reserved: quantity,
          reserved_by_user: reserved_by_user,
          reserved_at: reserved_at,
          expires_at: expires_at || (reserved_at + DEFAULT_EXPIRY_DAYS.days),
          over_reserved: over_reserved,
          override_authorized_by_user: override_authorized_by_user,
          override_authorized_at: over_reserved ? Time.current : nil,
          override_reason: override_reason
        )

        balance.quantity_reserved += quantity
        balance.quantity_available = balance.quantity_on_hand - balance.quantity_reserved
        balance.save!

        AuditEvents.record!(
          actor: reserved_by_user,
          event_name: "inventory_reservation.created",
          auditable: reservation,
          details: {
            "quantity" => quantity,
            "reservation_type" => reservation.reservation_type,
            "over_reserved" => over_reserved
          }
        )
      end
      reservation
    end

    private

    attr_reader :store, :variant, :quantity, :reserved_by_user, :customer, :customer_request_line,
                :special_order, :expires_at, :override_authorized_by_user, :override_reason
  end
end
