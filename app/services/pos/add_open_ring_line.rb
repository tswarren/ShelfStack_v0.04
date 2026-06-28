# frozen_string_literal: true

module Pos
  class AddOpenRingLine
    Error = Class.new(StandardError)

    def self.call!(transaction:, store:, register_session:, params:)
      new(transaction:, store:, register_session:, params:).call!
    end

    def initialize(transaction:, store:, register_session:, params:)
      @transaction = transaction
      @store = store
      @register_session = register_session
      @params = params
    end

    def call!
      sub_department = SubDepartment.active_records.find(params[:sub_department_id])
      quantity = params[:quantity].to_i
      quantity = 1 if quantity.zero?
      quantity = -quantity.abs if negative_line_entry?
      unit_price_cents = parse_dollar_param(params[:unit_price]) || 0

      tax = TaxCalculator.snapshot_for_subdepartment!(
        sub_department: sub_department,
        store: store,
        business_date: register_session&.business_date || Date.current,
        taxable_cents: unit_price_cents * quantity.abs
      )

      variant = params[:product_variant_id].presence && ProductVariant.find_by(id: params[:product_variant_id])
      return_line = quantity.negative?

      line = transaction.pos_transaction_lines.create!(
        line_number: next_line_number,
        line_type: "open_ring",
        product_variant: variant,
        product: variant&.product,
        quantity: quantity,
        unit_price_cents: unit_price_cents,
        line_discount_cents: 0,
        extended_price_cents: unit_price_cents * quantity.abs,
        tax_cents: tax.tax_cents,
        open_ring_description: params[:description].presence || "Open ring item",
        sub_department: sub_department,
        sub_department_name_snapshot: sub_department.name,
        tax_category: tax.tax_category,
        tax_rate_bps: tax.tax_rate_bps,
        store_tax_rate: tax.store_tax_rate,
        tax_identifier_snapshot: tax.store_tax_rate&.tax_identifier,
        store_tax_rate_short_name_snapshot: tax.store_tax_rate&.short_name,
        inventory_behavior_snapshot: variant&.inventory_behavior,
        return_disposition: (return_line ? "return_to_stock" : nil)
      )

      RecalculateTransaction.call!(transaction.reload)
      line
    rescue ActiveRecord::RecordNotFound
      raise Error, "Subdepartment could not be found."
    rescue TaxCalculator::MissingTaxError => e
      raise Error, e.message
    end

    private

    attr_reader :transaction, :store, :register_session, :params

    def next_line_number
      (transaction.pos_transaction_lines.maximum(:line_number) || 0) + 1
    end

    def negative_line_entry?
      entry_action = params[:entry_action].presence
      return true if entry_action == "return_no_receipt"

      ActiveModel::Type::Boolean.new.cast(params[:return_mode])
    end

    def parse_dollar_param(value)
      return if value.blank?

      normalized = value.to_s.delete_prefix("$")
      return unless normalized.match?(/\A\d+(?:\.\d{1,2})?\z/)

      (BigDecimal(normalized) * 100).round.to_i
    end
  end
end
