# frozen_string_literal: true

module InventoryReservations
  class ReserveIncoming
    class ReserveError < StandardError; end

    def self.call!(store:, variant:, quantity:, purchase_order_line:, reserved_by_user:,
                   customer: nil, customer_request_line: nil, special_order: nil)
      new(
        store:, variant:, quantity:, purchase_order_line:, reserved_by_user:,
        customer:, customer_request_line:, special_order:
      ).call!
    end

    def initialize(store:, variant:, quantity:, purchase_order_line:, reserved_by_user:,
                   customer: nil, customer_request_line: nil, special_order: nil)
      @store = store
      @variant = variant
      @quantity = quantity
      @purchase_order_line = purchase_order_line
      @reserved_by_user = reserved_by_user
      @customer = customer
      @customer_request_line = customer_request_line
      @special_order = special_order
    end

    def call!
      raise ReserveError, "Quantity must be positive" unless quantity.positive?

      reservation = InventoryReservation.create!(
        store: store,
        customer: customer,
        customer_request_line: customer_request_line,
        special_order: special_order,
        product_variant: variant,
        purchase_order_line: purchase_order_line,
        reservation_type: "incoming_reserve",
        status: "active",
        quantity_reserved: quantity,
        reserved_by_user: reserved_by_user,
        reserved_at: Time.current
      )

      AuditEvents.record!(
        actor: reserved_by_user,
        event_name: "inventory_reservation.created",
        auditable: reservation,
        details: { "quantity" => quantity, "reservation_type" => "incoming_reserve" }
      )
      reservation
    end

    private

    attr_reader :store, :variant, :quantity, :purchase_order_line, :reserved_by_user,
                :customer, :customer_request_line, :special_order
  end
end
