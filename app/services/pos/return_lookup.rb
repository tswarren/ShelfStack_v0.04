# frozen_string_literal: true

module Pos
  class ReturnLookup
    Result = Data.define(:status, :transaction, :lines, :message)

    def self.call(store:, transaction_number:)
      new(store:, transaction_number:).call
    end

    def initialize(store:, transaction_number:)
      @store = store
      @transaction_number = transaction_number.to_s.strip
    end

    def call
      if transaction_number.blank?
        return Result.new(status: :not_found, transaction: nil, lines: [], message: "Enter a receipt or transaction number.")
      end

      transaction = PosTransaction.completed_records.find_by(store: store, transaction_number: transaction_number)
      if transaction.blank?
        return Result.new(status: :not_found, transaction: nil, lines: [], message: "No completed transaction found.")
      end

      lines = transaction.pos_transaction_lines.map do |line|
        returned_qty = PosTransactionLine
          .joins(:pos_transaction)
          .where(source_transaction_line_id: line.id, pos_transactions: { status: "completed" })
          .sum(:quantity)
          .abs

        {
          id: line.id,
          line_number: line.line_number,
          sku: line.variant_sku_snapshot || line.product_variant&.sku,
          name: line.variant_name_snapshot || line.open_ring_description || line.product_variant&.name,
          sold_quantity: line.quantity.abs,
          returned_quantity: returned_qty,
          remaining_quantity: line.quantity.abs - returned_qty,
          unit_price_cents: line.unit_price_cents,
          effective_unit_price_cents: ReturnLinePricing.effective_unit_extended_cents(line),
          extended_price_cents: line.extended_price_cents,
          line_discount_cents: line.line_discount_cents
        }
      end

      Result.new(status: :found, transaction: transaction, lines: lines, message: nil)
    end

    private

    attr_reader :store, :transaction_number
  end
end
