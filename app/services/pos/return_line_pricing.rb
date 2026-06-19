# frozen_string_literal: true

module Pos
  class ReturnLinePricing
    Error = Class.new(StandardError)

    def self.apply!(line)
      new(line).apply!
    end

    def self.effective_unit_extended_cents(source_line)
      sold_quantity = source_line.quantity.abs
      return source_line.extended_price_cents if sold_quantity <= 1

      (source_line.extended_price_cents.to_f / sold_quantity).round
    end

    def initialize(line)
      @line = line
    end

    def apply!
      source_line = line.source_transaction_line
      raise Error, "Return line must reference a source sale line." if source_line.blank?
      raise Error, "Source sale line must be from a completed transaction." unless source_line.pos_transaction.completed?

      return_quantity = line.quantity.abs
      sold_quantity = source_line.quantity.abs
      raise Error, "Return quantity exceeds sold quantity." if return_quantity > sold_quantity

      line.unit_price_cents = self.class.effective_unit_extended_cents(source_line)
      line.line_discount_cents = prorate(source_line.line_discount_cents, return_quantity, sold_quantity)
      line.extended_price_cents = prorate(source_line.extended_price_cents, return_quantity, sold_quantity)
      line.tax_cents = prorate(source_line.tax_cents, return_quantity, sold_quantity)
      line.tax_category_id = source_line.tax_category_id
      line.tax_rate_bps = source_line.tax_rate_bps
      line.store_tax_rate_id = source_line.store_tax_rate_id
      line.tax_identifier_snapshot = source_line.tax_identifier_snapshot
      line.store_tax_rate_short_name_snapshot = source_line.store_tax_rate_short_name_snapshot
      line.sub_department_id = source_line.sub_department_id
      line.save!
      line
    end

    private

    attr_reader :line

    def prorate(amount_cents, return_quantity, sold_quantity)
      ((amount_cents * return_quantity) / sold_quantity.to_f).round
    end
  end
end
