# frozen_string_literal: true

module Pos
  class CustomerPickupLookup
    PickupRow = Data.define(
      :reservation_id,
      :customer_id,
      :customer_name,
      :request_number,
      :request_id,
      :variant_sku,
      :variant_name,
      :quantity,
      :expires_at,
      :reservation_type
    )

    def self.ready_for_store(store:, query: nil, request_number: nil)
      new(store:, query:, request_number:).ready_rows
    end

    def initialize(store:, query: nil, request_number: nil)
      @store = store
      @query = query.to_s.strip
      @request_number = request_number.to_s.strip
    end

    def ready_rows
      scope = base_scope
      scope = filter_by_query(scope) if query.present?
      scope = filter_by_request_number(scope) if request_number.present?

      scope.map { |reservation| row_for(reservation) }
    end

    private

    attr_reader :store, :query, :request_number

    def base_scope
      InventoryReservation
        .where(store: store, status: %w[active ready], reservation_type: %w[on_hand_hold special_order_reserve])
        .includes(
          :customer,
          :product_variant,
          customer_request_line: { customer_request: :customer }
        )
        .order(:expires_at, :created_at)
    end

    def filter_by_query(scope)
      customer_ids = Customer.active_records
                             .where("display_name ILIKE :q OR email ILIKE :q OR phone ILIKE :q", q: "%#{query}%")
                             .limit(25)
                             .pluck(:id)
      snapshot_ids = scope.joins(customer_request_line: :customer_request)
                          .where(customer_requests: { store_id: store.id })
                          .where(
                            "customer_requests.customer_name_snapshot ILIKE :q OR " \
                            "customer_requests.customer_email_snapshot ILIKE :q OR " \
                            "customer_requests.customer_phone_snapshot ILIKE :q",
                            q: "%#{query}%"
                          )
                          .select(:id)

      scope.where(customer_id: customer_ids).or(scope.where(id: snapshot_ids))
    end

    def filter_by_request_number(scope)
      request_ids = CustomerRequest.where(store: store)
                                   .where("request_number ILIKE ?", "%#{request_number}%")
                                   .limit(25)
                                   .pluck(:id)
      scope.joins(:customer_request_line)
           .where(customer_request_lines: { customer_request_id: request_ids })
    end

    def row_for(reservation)
      request = reservation.customer_request_line&.customer_request

      PickupRow.new(
        reservation_id: reservation.id,
        customer_id: reservation.customer_id || request&.customer_id,
        customer_name: CustomerDemand::DisplayName.for_reservation(reservation),
        request_number: request&.request_number,
        request_id: request&.id,
        variant_sku: reservation.product_variant.sku,
        variant_name: reservation.product_variant.name,
        quantity: reservation.remaining_quantity,
        expires_at: reservation.expires_at,
        reservation_type: reservation.reservation_type
      )
    end
  end
end
