# frozen_string_literal: true

module Pos
  class AddReturnLine
    Error = Class.new(StandardError)

    def self.call!(transaction:, store:, params:)
      new(transaction:, store:, params:).call!
    end

    def initialize(transaction:, store:, params:)
      @transaction = transaction
      @store = store
      @params = params
    end

    def call!
      source_line = PosTransactionLine
        .joins(:pos_transaction)
        .where(pos_transactions: { store: store, status: "completed" })
        .find(params[:source_transaction_line_id])

      quantity = -params[:quantity].to_i.abs
      quantity = -1 if quantity.zero?

      line_attrs = {
        line_number: next_line_number,
        quantity: quantity,
        unit_price_cents: 0,
        line_discount_cents: 0,
        extended_price_cents: 0,
        tax_cents: 0,
        source_transaction: source_line.pos_transaction,
        source_transaction_line: source_line,
        source_sold_quantity_snapshot: source_line.quantity.abs,
        return_disposition: params[:return_disposition].presence || "return_to_stock"
      }

      if source_line.open_ring_line?
        line_attrs.merge!(
          line_type: "open_ring",
          open_ring_description: source_line.open_ring_description,
          sub_department: source_line.sub_department,
          sub_department_name_snapshot: source_line.sub_department_name_snapshot.presence || source_line.sub_department&.name,
          tax_category: source_line.tax_category,
          tax_rate_bps: source_line.tax_rate_bps,
          store_tax_rate: source_line.store_tax_rate,
          tax_identifier_snapshot: source_line.tax_identifier_snapshot,
          store_tax_rate_short_name_snapshot: source_line.store_tax_rate_short_name_snapshot,
          inventory_behavior_snapshot: source_line.inventory_behavior_snapshot
        )
      else
        line_attrs.merge!(
          line_type: "variant",
          product_variant: source_line.product_variant,
          product: source_line.product
        )
      end

      line = transaction.pos_transaction_lines.create!(line_attrs)

      Pos::ReturnLinePricing.apply!(line)
      Pos::RecalculateTransaction.call!(transaction.reload)
      line
    rescue ActiveRecord::RecordNotFound
      raise Error, "Source sale line not found."
    end

    private

    attr_reader :transaction, :store, :params

    def next_line_number
      transaction.pos_transaction_lines.maximum(:line_number).to_i + 1
    end
  end
end
