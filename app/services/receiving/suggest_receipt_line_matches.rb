# frozen_string_literal: true

module Receiving
  class SuggestReceiptLineMatches
    Suggestion = Data.define(
      :receipt_line,
      :purchase_order_line,
      :quantity_matched,
      :match_source
    )

    def self.call(receipt:)
      new(receipt:).call
    end

    def initialize(receipt:)
      @receipt = receipt
    end

    def call
      suggestions = []
      receipt.receipt_lines.each do |receipt_line|
        next if receipt_line.quantity_accepted.zero?

        remaining = receipt_line.quantity_accepted
        PoLineMatchCandidates.call(receipt_line: receipt_line).each do |candidate|
          break if remaining.zero?

          qty = [ remaining, candidate.open_to_receive_quantity ].min
          next if qty <= 0

          suggestions << Suggestion.new(
            receipt_line: receipt_line,
            purchase_order_line: candidate.purchase_order_line,
            quantity_matched: qty,
            match_source: "auto"
          )
          remaining -= qty
        end
      end
      suggestions
    end

    private

    attr_reader :receipt
  end
end
