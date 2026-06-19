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
      clear_return_line_transaction_discounts!

      lines = discountable_lines
      return if lines.empty?

      discountable_total = lines.sum { |line| discountable_line_base(line) }
      transaction_discount = transaction.discount_cents.to_i
      if transaction_discount.zero? || discountable_total.zero?
        lines.each { |line| line.update!(transaction_discount_cents: 0) }
        return
      end

      remaining_discount = transaction_discount
      lines.each_with_index do |line, index|
        line_base = discountable_line_base(line)
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

    def discountable_lines
      transaction.pos_transaction_lines.reject(&:return_line?)
    end

    def discountable_line_base(line)
      [line.unit_price_cents * line.quantity.abs - line.line_discount_cents, 0].max
    end

    def clear_return_line_transaction_discounts!
      transaction.pos_transaction_lines.select(&:return_line?).each do |line|
        next if line.transaction_discount_cents.zero?

        line.update!(transaction_discount_cents: 0)
      end
    end
  end
end
