# frozen_string_literal: true

module Pos
  class RecalculateTransaction
    def self.call!(transaction, business_date: nil)
      new(transaction, business_date:).call!
    end

    def initialize(transaction, business_date: nil)
      @transaction = transaction
      @business_date = business_date || transaction.business_date || Date.current
    end

    def call!
      transaction.pos_transaction_lines.each do |line|
        if sourced_return_line?(line)
          ReturnLinePricing.apply!(line)
        else
          recalculate_line_base!(line)
        end
      end

      discount_phase!

      transaction.pos_transaction_lines.reset
      TaxRecalculator.call!(transaction, business_date: business_date)

      transaction.subtotal_cents = transaction.pos_transaction_lines.sum do |line|
        signed_line_amount(line, line.unit_price_cents * line.quantity.abs)
      end
      transaction.tax_cents = transaction.pos_transaction_lines.sum do |line|
        signed_line_amount(line, line.tax_cents)
      end
      transaction.normal_tax_cents = transaction.pos_transaction_lines.sum do |line|
        signed_line_amount(line, line.normal_tax_cents)
      end
      transaction.pos_transaction_lines.reset
      transaction.total_cents = transaction.pos_transaction_lines.sum do |line|
        signed_line_amount(line, line.extended_price_cents + line.tax_cents)
      end + transaction.rounding_cents.to_i
      transaction.transaction_type = DeriveTransactionType.call(transaction)
      transaction.save!
      transaction
    end

    private

    attr_reader :transaction, :business_date

    def recalculate_line_base!(line)
      base = line.unit_price_cents * line.quantity.abs
      line.extended_price_cents = base
      line.transaction_discount_cents = 0 if line.return_line?
      line.save! if line.changed?
    end

    def discount_phase!
      if transaction.pos_discount_applications.active_records.exists?
        DiscountRecalculator.call!(transaction)
      else
        legacy_discount_phase!
      end
    end

    def legacy_discount_phase!
      transaction.pos_transaction_lines.each do |line|
        next if sourced_return_line?(line)

        recalculate_legacy_line_discount!(line)
      end

      DiscountCalculator.apply_transaction_discount!(transaction)
    end

    def recalculate_legacy_line_discount!(line)
      base = line.unit_price_cents * line.quantity.abs
      line_discount = [ line.line_discount_cents.to_i, base ].min
      line.line_discount_cents = line_discount if line.line_discount_cents.to_i != line_discount
      line.extended_price_cents = [ base - line_discount, 0 ].max
      line.save! if line.changed?
    end

    def sourced_return_line?(line)
      line.return_line? && line.source_transaction_line_id.present?
    end

    def signed_line_amount(line, magnitude_cents)
      line.quantity.negative? ? -magnitude_cents : magnitude_cents
    end
  end
end
