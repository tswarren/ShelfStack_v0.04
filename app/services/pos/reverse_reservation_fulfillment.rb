# frozen_string_literal: true

module Pos
  class ReverseReservationFulfillment
    def self.call!(transaction:, reversed_by_user:)
      new(transaction:, reversed_by_user:).call!
    end

    def initialize(transaction:, reversed_by_user:)
      @transaction = transaction
      @reversed_by_user = reversed_by_user
    end

    def call!
      transaction.pos_transaction_lines.each do |line|
        next if line.inventory_reservation_id.blank?

        reservation = line.inventory_reservation
        next unless reservation.status == "fulfilled"

        InventoryReservations::ReverseFulfillment.call!(
          reservation: reservation,
          reversed_by_user: reversed_by_user,
          quantity: line.quantity.abs
        )
      end
    end

    private

    attr_reader :transaction, :reversed_by_user
  end
end
