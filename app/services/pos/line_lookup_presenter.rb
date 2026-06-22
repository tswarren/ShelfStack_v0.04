# frozen_string_literal: true

module Pos
  class LineLookupPresenter
    def self.as_json(result, store:)
      new(result, store:).as_json
    end

    def initialize(result, store:)
      @result = result
      @store = store
    end

    def as_json
      {
        status: result.status.to_s,
        message: result.message,
        variants: result.variants.map { |variant| variant_json(variant) }
      }
    end

    private

    attr_reader :result, :store

    def variant_json(variant)
      balance = InventoryBalance.find_by(store: store, product_variant: variant)
      on_hand = balance&.quantity_on_hand || 0
      available = Inventory::Availability.available(store: store, variant: variant) || 0
      reserved = Inventory::Availability.reserved(store: store, variant: variant)
      ready_reservations = ready_reservations_for(variant)

      {
        id: variant.id,
        sku: variant.sku,
        name: variant.name,
        product_name: variant.product.name,
        condition: variant.condition&.short_name,
        selling_price_cents: variant.selling_price_cents,
        inventory_behavior: variant.inventory_behavior,
        active: variant.active?,
        product_active: variant.product.active?,
        quantity_on_hand: on_hand,
        quantity_available: available,
        quantity_reserved: reserved,
        ready_reservations: ready_reservations
      }
    end

    def ready_reservations_for(variant)
      InventoryReservation
        .where(store: store, product_variant: variant, status: %w[active ready],
               reservation_type: %w[on_hand_hold special_order_reserve])
        .includes(:customer, customer_request_line: { customer_request: :customer })
        .limit(10)
        .map do |reservation|
          request = reservation.customer_request_line&.customer_request
          {
            id: reservation.id,
            customer_name: CustomerDemand::DisplayName.for_reservation(reservation),
            request_number: request&.request_number,
            expires_at: reservation.expires_at&.iso8601,
            quantity: reservation.remaining_quantity
          }
        end
    end
  end
end
