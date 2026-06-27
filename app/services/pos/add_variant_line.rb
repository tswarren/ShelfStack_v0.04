# frozen_string_literal: true

module Pos
  class AddVariantLine
    Error = Class.new(StandardError)

    def self.call!(transaction:, variant:, quantity: 1, unit_price_cents: nil, entry_action: "sale")
      new(
        transaction: transaction,
        variant: variant,
        quantity: quantity,
        unit_price_cents: unit_price_cents,
        entry_action: entry_action
      ).call!
    end

    def initialize(transaction:, variant:, quantity: 1, unit_price_cents: nil, entry_action: "sale")
      @transaction = transaction
      @variant = variant
      @quantity = quantity.to_i
      @quantity = 1 if @quantity.zero?
      @unit_price_cents = unit_price_cents
      @entry_action = entry_action.to_s
    end

    def call!
      raise Error, "Transaction is not editable." unless transaction.editable?

      qty = quantity
      qty = -qty.abs if negative_line_entry? && qty.positive?
      price = unit_price_cents || variant.selling_price_cents

      line = transaction.pos_transaction_lines.create!(
        line_number: next_line_number,
        line_type: "variant",
        product_variant: variant,
        product: variant.product,
        quantity: qty,
        unit_price_cents: price,
        line_discount_cents: 0,
        extended_price_cents: 0,
        tax_cents: 0,
        return_disposition: (negative_line_entry? ? "return_to_stock" : nil)
      )

      RecalculateTransaction.call!(transaction.reload)
      line
    end

    private

    attr_reader :transaction, :variant, :quantity, :unit_price_cents, :entry_action

    def next_line_number
      (transaction.pos_transaction_lines.maximum(:line_number) || 0) + 1
    end

    def negative_line_entry?
      entry_action.in?(%w[return return_no_receipt])
    end
  end
end
