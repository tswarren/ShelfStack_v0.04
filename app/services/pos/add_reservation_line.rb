# frozen_string_literal: true

module Pos
  class AddReservationLine
    Error = Class.new(StandardError)

    def self.call!(transaction:, reservation:, added_by_user:)
      new(transaction:, reservation:, added_by_user:).call!
    end

    def initialize(transaction:, reservation:, added_by_user:)
      @transaction = transaction
      @reservation = reservation
      @added_by_user = added_by_user
    end

    def call!
      raise Error, "Reservation must be active or ready" unless %w[active ready].include?(reservation.status)
      raise Error, "Store mismatch" if reservation.store_id != transaction.store_id

      variant = reservation.product_variant
      line = transaction.pos_transaction_lines.create!(
        line_type: "variant",
        product_variant: variant,
        quantity: 1,
        unit_price_cents: variant.selling_price_cents,
        inventory_reservation: reservation,
        special_order: reservation.special_order,
        customer_request_line: reservation.customer_request_line
      )

      transaction.update!(customer: reservation.customer) if reservation.customer.present?

      line
    end

    private

    attr_reader :transaction, :reservation, :added_by_user
  end
end
