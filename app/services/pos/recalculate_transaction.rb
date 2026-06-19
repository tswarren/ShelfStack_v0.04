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
        recalculate_line!(line)
      end

      DiscountCalculator.apply_transaction_discount!(transaction)

      transaction.pos_transaction_lines.each do |line|
        next if sourced_return_line?(line)

        apply_line_tax!(line)
      end

      transaction.subtotal_cents = transaction.pos_transaction_lines.sum do |line|
        signed_line_amount(line, line.unit_price_cents * line.quantity.abs)
      end
      transaction.tax_cents = transaction.pos_transaction_lines.sum do |line|
        signed_line_amount(line, line.tax_cents)
      end
      transaction.total_cents = transaction.pos_transaction_lines.sum do |line|
        signed_line_amount(line, line.extended_price_cents + line.tax_cents)
      end + transaction.rounding_cents.to_i
      transaction.transaction_type = DeriveTransactionType.call(transaction)
      transaction.save!
      transaction
    end

    private

    attr_reader :transaction, :business_date

    def recalculate_line!(line)
      if sourced_return_line?(line)
        ReturnLinePricing.apply!(line)
        return
      end

      base = line.unit_price_cents * line.quantity.abs
      line.extended_price_cents = [base - line.line_discount_cents.to_i, 0].max
    end

    def sourced_return_line?(line)
      line.return_line? && line.source_transaction_line_id.present?
    end

    def signed_line_amount(line, magnitude_cents)
      line.quantity.negative? ? -magnitude_cents : magnitude_cents
    end

    def apply_line_tax!(line)
      return if line.open_ring_line? && line.tax_category_id.blank?

      if line.variant_line? && line.product_variant.present?
        tax = TaxCalculator.snapshot_for_variant!(
          variant: line.product_variant,
          store: transaction.store,
          business_date: business_date,
          taxable_cents: line.extended_price_cents
        )
        LineTaxSnapshot.apply!(
          line,
          tax_category: tax.tax_category,
          store_tax_rate: tax.store_tax_rate,
          tax_rate_bps: tax.tax_rate_bps,
          tax_cents: tax.tax_cents
        )
        line.sub_department = line.product_variant.sub_department
        line.inventory_behavior_snapshot = line.product_variant.inventory_behavior
      elsif line.tax_category.present? && line.tax_rate_bps.present?
        store_tax_rate = TaxRateLookup.call(
          store: transaction.store,
          tax_category: line.tax_category,
          date: business_date
        )
        tax_cents = ((line.extended_price_cents * line.tax_rate_bps) / 10_000.0).round
        LineTaxSnapshot.apply!(
          line,
          tax_category: line.tax_category,
          store_tax_rate: store_tax_rate,
          tax_rate_bps: line.tax_rate_bps,
          tax_cents: tax_cents
        )
      else
        line.tax_cents = 0
        line.tax_identifier_snapshot = nil
        line.store_tax_rate_short_name_snapshot = nil
        line.store_tax_rate = nil
      end
      line.save!
    end
  end
end
