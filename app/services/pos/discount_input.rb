# frozen_string_literal: true

module Pos
  class DiscountInput
    Error = Class.new(StandardError)

    INPUT_TYPES = %w[amount percent].freeze

    def self.resolve_cents(value:, input_type:, base_cents:)
      new(value:, input_type:, base_cents:).resolve_cents
    end

    def self.discountable_transaction_base_cents(transaction)
      transaction.pos_transaction_lines.reject(&:return_line?).sum do |line|
        line_base_cents(line) - line.line_discount_cents.to_i
      end.clamp(0..)
    end

    def self.line_base_cents(line)
      line.unit_price_cents * line.quantity.abs
    end

    def initialize(value:, input_type:, base_cents:)
      @value = value
      @input_type = input_type.to_s.presence || "amount"
      @base_cents = base_cents.to_i
    end

    def resolve_cents
      return 0 if value.blank?

      case input_type
      when "amount"
        parse_amount_cents
      when "percent"
        parse_percent_cents
      else
        raise Error, "Invalid discount type."
      end
    end

    private

    attr_reader :value, :input_type, :base_cents

    def parse_amount_cents
      [(BigDecimal(value.to_s) * 100).round.to_i, 0].max
    end

    def parse_percent_cents
      percent = BigDecimal(value.to_s)
      raise Error, "Percent must be between 0 and 100." if percent.negative? || percent > 100
      return 0 if base_cents.zero?

      ((base_cents * percent) / 100).round
    end
  end
end
