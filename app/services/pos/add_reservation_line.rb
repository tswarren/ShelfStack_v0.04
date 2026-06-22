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
      validate_demand_chain!

      raise Error, "Reservation must be active or ready" unless %w[active ready].include?(reservation.status)
      raise Error, "Store mismatch" if reservation.store_id != transaction.store_id

      remaining = reservation.remaining_quantity
      raise Error, "Reservation has no remaining quantity" if remaining <= 0

      variant = reservation.product_variant
      line = transaction.pos_transaction_lines.create!(
        line_number: next_line_number,
        line_type: "variant",
        product_variant: variant,
        product: variant.product,
        quantity: 1,
        unit_price_cents: variant.selling_price_cents,
        line_discount_cents: 0,
        extended_price_cents: 0,
        tax_cents: 0,
        inventory_reservation: reservation,
        special_order: reservation.special_order,
        customer_request_line: reservation.customer_request_line
      )

      transaction.update!(customer: reservation.customer) if reservation.customer.present?

      Pos::RecalculateTransaction.call!(transaction.reload)
      line
    end

    private

    attr_reader :transaction, :reservation, :added_by_user

    def next_line_number
      (transaction.pos_transaction_lines.maximum(:line_number) || 0) + 1
    end

    def validate_demand_chain!
      if reservation.special_order_id.present? &&
         reservation.customer_request_line_id.present? &&
         reservation.special_order.customer_request_line_id != reservation.customer_request_line_id
        raise Error, "Reservation special order and request line do not match"
      end

      if reservation.customer_id.present? && reservation.customer_request_line&.customer_request&.customer_id.present? &&
         reservation.customer_id != reservation.customer_request_line.customer_request.customer_id
        raise Error, "Reservation customer does not match request customer"
      end

      if reservation.special_order_id.present? && reservation.customer_id.present? &&
         reservation.special_order.customer_id != reservation.customer_id
        raise Error, "Reservation customer does not match special order customer"
      end
    end
  end
end
