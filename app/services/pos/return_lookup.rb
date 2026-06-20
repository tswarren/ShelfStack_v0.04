# frozen_string_literal: true

module Pos
  class ReturnLookup
    Result = Data.define(:status, :transaction, :lines, :message)

    def self.call(store:, transaction_number:)
      new(store:, transaction_number:).call
    end

    def initialize(store:, transaction_number:)
      @store = store
      @transaction_number = transaction_number.to_s.strip
    end

    def call
      if transaction_number.blank?
        return Result.new(status: :not_found, transaction: nil, lines: [], message: "Enter a receipt or transaction number.")
      end

      transaction = PosTransaction.completed_records.find_by(store: store, transaction_number: transaction_number)
      if transaction.blank?
        return Result.new(status: :not_found, transaction: nil, lines: [], message: "No completed transaction found.")
      end

      sale_transaction, message = resolve_sale_transaction(transaction)
      if sale_transaction.blank?
        return Result.new(status: :not_found, transaction: nil, lines: [], message: message)
      end

      lines = sale_lines_for_return(sale_transaction).map { |line| build_line_entry(line) }

      Result.new(status: :found, transaction: sale_transaction, lines: lines, message: message)
    end

    private

    attr_reader :store, :transaction_number

    def resolve_sale_transaction(transaction)
      return [ transaction, nil ] unless transaction.transaction_type == "return"

      source_transactions = transaction.pos_transaction_lines.filter_map do |line|
        source = line.source_transaction if line.source_transaction&.completed?
        source ||= line.source_transaction_line&.pos_transaction if line.source_transaction_line&.pos_transaction&.completed?
        source if source&.store_id == store.id
      end.uniq

      if source_transactions.empty?
        return [ nil, "This is a return receipt. Enter the original sale receipt number." ]
      end

      if source_transactions.size > 1
        return [ nil, "This return receipt references multiple sales. Enter the original sale receipt number." ]
      end

      source = source_transactions.first
      message = "Showing original sale receipt #{source.transaction_number}."
      [ source, message ]
    end

    def sale_lines_for_return(transaction)
      transaction.pos_transaction_lines.select do |line|
        line.merchandise_line? && line.quantity.positive?
      end
    end

    def build_line_entry(line)
      returned_qty = returned_quantity_for(line)
      remaining = line.quantity - returned_qty
      returnable = remaining.positive?

      {
        id: line.id,
        line_number: line.line_number,
        line_type: line.line_type,
        sku: line_sku(line),
        name: line_name(line),
        open_ring_description: line.open_ring_description,
        sub_department_id: line.sub_department_id,
        sub_department_name: line.sub_department_name_snapshot.presence || line.sub_department&.name,
        sold_quantity: line.quantity,
        returned_quantity: returned_qty,
        remaining_quantity: remaining,
        returnable: returnable,
        unit_price_cents: line.unit_price_cents,
        effective_unit_price_cents: ReturnLinePricing.effective_unit_extended_cents(line),
        extended_price_cents: line.extended_price_cents,
        line_discount_cents: line.line_discount_cents
      }
    end

    def returned_quantity_for(line)
      PosTransactionLine
        .joins(:pos_transaction)
        .where(source_transaction_line_id: line.id, pos_transactions: { status: "completed", store_id: store.id })
        .sum(:quantity)
        .abs
    end

    def line_sku(line)
      if line.open_ring_line?
        line.sub_department_name_snapshot.presence || line.sub_department&.name || "Open ring"
      else
        line.variant_sku_snapshot || line.product_variant&.sku
      end
    end

    def line_name(line)
      if line.open_ring_line?
        line.open_ring_description
      else
        line.variant_name_snapshot || line.product_variant&.name
      end
    end
  end
end
