# frozen_string_literal: true

module Pos
  class TaxRecalculator
    APPLIED_TAX_SOURCES = %w[normal non_taxable transaction_exemption sourced_return line_override].freeze

    def self.call!(transaction, business_date:)
      new(transaction, business_date:).call!
    end

    def initialize(transaction, business_date:)
      @transaction = transaction
      @business_date = business_date.to_date
      @active_exemption = transaction.pos_tax_exemptions.active_records.first
      @active_overrides_by_line_id = transaction.pos_line_tax_overrides.active_records.index_by(&:pos_transaction_line_id)
    end

    def call!
      transaction.pos_transaction_lines.each do |line|
        next if sourced_return_line?(line)

        recalculate_line_tax!(line)
        line.save!
      end

      transaction
    end

    private

    attr_reader :transaction, :business_date, :active_exemption, :active_overrides_by_line_id

    def recalculate_line_tax!(line)
      if gift_card_sale_line?(line)
        apply_gift_card_tax!(line)
        return
      end

      if open_ring_without_category?(line)
        apply_zero_tax!(line, applied_source: "non_taxable")
        return
      end

      normal_tax = calculate_normal_tax(line)
      apply_normal_tax!(line, normal_tax)

      if active_override = active_overrides_by_line_id[line.id]
        apply_line_override!(line, active_override)
      elsif active_exemption.present? && exemption_eligible?(line)
        apply_exemption!(line)
      elsif normal_tax.tax_cents.zero?
        line.applied_tax_source = "non_taxable"
        copy_normal_to_final!(line, normal_tax)
      else
        line.applied_tax_source = "normal"
        copy_normal_to_final!(line, normal_tax)
      end
    end

    def calculate_normal_tax(line)
      if line.variant_line? && line.product_variant.present?
        TaxCalculator.snapshot_for_variant!(
          variant: line.product_variant,
          store: transaction.store,
          business_date: business_date,
          taxable_cents: line.extended_price_cents
        )
      elsif line.tax_category.present? && line.tax_rate_bps.present?
        store_tax_rate = TaxRateLookup.call(
          store: transaction.store,
          tax_category: line.tax_category,
          date: business_date
        )
        tax_cents = ((line.extended_price_cents * line.tax_rate_bps) / 10_000.0).round
        TaxCalculator::LineTax.new(
          tax_category: line.tax_category,
          store_tax_rate: store_tax_rate,
          tax_rate_bps: line.tax_rate_bps,
          tax_cents: tax_cents
        )
      else
        TaxCalculator::LineTax.new(
          tax_category: nil,
          store_tax_rate: nil,
          tax_rate_bps: nil,
          tax_cents: 0
        )
      end
    end

    def apply_normal_tax!(line, tax)
      if tax.tax_category.present?
        LineTaxSnapshot.apply_normal!(
          line,
          tax_category: tax.tax_category,
          store_tax_rate: tax.store_tax_rate,
          tax_rate_bps: tax.tax_rate_bps,
          tax_cents: tax.tax_cents
        )
      else
        LineTaxSnapshot.zero_normal!(line)
      end

      if line.variant_line? && line.product_variant.present?
        line.sub_department = line.product_variant.sub_department
        line.inventory_behavior_snapshot = line.product_variant.inventory_behavior
      end
    end

    def copy_normal_to_final!(line, tax)
      if tax.tax_category.present?
        LineTaxSnapshot.apply_final!(
          line,
          tax_category: tax.tax_category,
          store_tax_rate: tax.store_tax_rate,
          tax_rate_bps: tax.tax_rate_bps,
          tax_cents: tax.tax_cents
        )
      else
        LineTaxSnapshot.zero_final!(line)
      end
    end

    def apply_line_override!(line, override)
      rate = TaxRateLookup.call(
        store: transaction.store,
        tax_category: override.override_tax_category,
        date: business_date
      )
      tax_cents = ((line.extended_price_cents * rate.tax_rate_bps) / 10_000.0).round

      override.update!(
        override_store_tax_rate: rate,
        override_tax_rate_bps: rate.tax_rate_bps,
        override_tax_identifier_snapshot: rate.tax_identifier,
        override_store_tax_rate_short_name_snapshot: rate.short_name
      )

      if active_exemption.present? && exemption_eligible?(line)
        apply_exemption!(line)
        return
      end

      LineTaxSnapshot.apply_final!(
        line,
        tax_category: override.override_tax_category,
        store_tax_rate: rate,
        tax_rate_bps: rate.tax_rate_bps,
        tax_cents: tax_cents
      )
      line.applied_tax_source = "line_override"
    end

    def apply_exemption!(line)
      line.applied_tax_source = "transaction_exemption"
      if line.normal_tax_category_id.present?
        LineTaxSnapshot.apply_final!(
          line,
          tax_category: line.normal_tax_category,
          store_tax_rate: line.normal_store_tax_rate,
          tax_rate_bps: line.normal_tax_rate_bps,
          tax_cents: 0
        )
      else
        LineTaxSnapshot.zero_final!(line)
      end
    end

    def apply_gift_card_tax!(line)
      LineTaxSnapshot.zero_normal!(line)
      LineTaxSnapshot.zero_final!(line)
      line.applied_tax_source = "non_taxable"
    end

    def apply_zero_tax!(line, applied_source:)
      LineTaxSnapshot.zero_normal!(line)
      LineTaxSnapshot.zero_final!(line)
      line.applied_tax_source = applied_source
    end

    def exemption_eligible?(line)
      return false unless line.quantity.positive?
      return false if gift_card_sale_line?(line)
      return false if open_ring_without_category?(line)

      true
    end

    def gift_card_sale_line?(line)
      line.gift_card_sale_line?
    end

    def open_ring_without_category?(line)
      line.open_ring_line? && line.tax_category_id.blank?
    end

    def sourced_return_line?(line)
      line.return_line? && line.source_transaction_line_id.present?
    end
  end
end
