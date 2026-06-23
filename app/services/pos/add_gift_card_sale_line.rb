# frozen_string_literal: true

module Pos
  class AddGiftCardSaleLine
    Error = Class.new(StandardError)

    def self.call!(transaction:, actor:, amount_cents:, line_number:)
      new(transaction:, actor:, amount_cents:, line_number:).call!
    end

    def initialize(transaction:, actor:, amount_cents:, line_number:)
      @transaction = transaction
      @actor = actor
      @amount_cents = amount_cents
      @line_number = line_number
    end

    def call!
      raise Error, "Transaction is not editable." unless transaction.editable?
      authorize!

      amount = GiftCardSaleSupport.validate_amount!(amount_cents)
      sub_department = GiftCardSaleSupport.default_sub_department!
      business_date = transaction.business_date || Date.current
      tax = TaxCalculator.snapshot_for_subdepartment!(
        sub_department: sub_department,
        store: transaction.store,
        business_date: business_date,
        taxable_cents: amount
      )

      line = transaction.pos_transaction_lines.create!(
        line_number: line_number,
        line_type: "gift_card_sale",
        quantity: 1,
        unit_price_cents: amount,
        line_discount_cents: 0,
        extended_price_cents: amount,
        tax_cents: tax.tax_cents,
        open_ring_description: PosTransactionLine::GIFT_CARD_SALE_DESCRIPTION,
        sub_department: sub_department,
        sub_department_name_snapshot: sub_department.name,
        tax_category: tax.tax_category,
        tax_rate_bps: tax.tax_rate_bps,
        store_tax_rate: tax.store_tax_rate,
        tax_identifier_snapshot: tax.store_tax_rate&.tax_identifier,
        store_tax_rate_short_name_snapshot: tax.store_tax_rate&.short_name,
        inventory_behavior_snapshot: "pure_financial",
        generate_stored_value_identifier: true
      )

      RecalculateTransaction.call!(transaction.reload)
      line
    rescue TaxCalculator::MissingTaxError => e
      raise Error, e.message
    end

    private

    attr_reader :transaction, :actor, :amount_cents, :line_number

    def authorize!
      return if GiftCardSalePolicy.issue_permitted?(actor:, store: transaction.store)

      raise Error, "You are not authorized to sell gift cards at POS."
    end
  end
end
