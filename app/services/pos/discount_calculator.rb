# frozen_string_literal: true

module Pos
  class DiscountCalculator
    def self.apply_transaction_discount!(transaction)
      new(transaction).apply_transaction_discount!
    end

    def initialize(transaction)
      @transaction = transaction
    end

    def apply_transaction_discount!
      lines = transaction.pos_transaction_lines.reject do |line|
        line.return_line? && line.source_transaction_line_id.present?
      end
      return if lines.empty?

      discountable_total = lines.sum { |line| [line.unit_price_cents * line.quantity.abs - line.line_discount_cents, 0].max }
      transaction_discount = transaction.discount_cents.to_i
      if transaction_discount.zero? || discountable_total.zero?
        lines.each { |line| line.update!(transaction_discount_cents: 0) }
        return
      end

      remaining_discount = transaction_discount
      lines.each_with_index do |line, index|
        line_base = [line.unit_price_cents * line.quantity.abs - line.line_discount_cents, 0].max
        share = if index == lines.length - 1
                  remaining_discount
                else
                  ((transaction_discount * line_base) / discountable_total.to_f).round
                end
        remaining_discount -= share
        line.update!(
          extended_price_cents: line_base - share,
          transaction_discount_cents: share
        )
      end
    end

    private

    attr_reader :transaction
  end
end
