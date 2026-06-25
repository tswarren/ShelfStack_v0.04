# frozen_string_literal: true

module Pos
  class OperationalMarginReport
    Row = Data.define(
      :pos_transaction_line_id,
      :transaction_number,
      :business_date,
      :sku,
      :variant_name,
      :quantity,
      :net_revenue_cents,
      :total_cogs_cents,
      :cogs_estimated,
      :revenue_treatment
    )

    Summary = Data.define(
      :net_revenue_cents,
      :total_cogs_cents,
      :actual_margin_cents,
      :estimated_margin_cents,
      :unknown_cost_revenue_cents,
      :rows
    )

    def self.call(scope:)
      new(scope:).call
    end

    def initialize(scope:)
      @scope = scope
    end

    def call
      rows = line_scope.map { |line| build_row(line) }

      merchandise_rows = rows.select { |row| row.revenue_treatment == "merchandise" }
      unknown_rows = merchandise_rows.select { |row| row.total_cogs_cents.nil? }
      estimated_rows = merchandise_rows.select { |row| row.cogs_estimated && row.total_cogs_cents.present? }
      actual_rows = merchandise_rows.reject(&:cogs_estimated).select { |row| row.total_cogs_cents.present? }

      net_revenue = merchandise_rows.sum(&:net_revenue_cents)
      total_cogs = merchandise_rows.sum { |row| row.total_cogs_cents.to_i }

      Summary.new(
        net_revenue_cents: net_revenue,
        total_cogs_cents: total_cogs,
        actual_margin_cents: actual_rows.sum(&:net_revenue_cents) - actual_rows.sum { |row| row.total_cogs_cents.to_i },
        estimated_margin_cents: estimated_rows.sum(&:net_revenue_cents) - estimated_rows.sum { |row| row.total_cogs_cents.to_i },
        unknown_cost_revenue_cents: unknown_rows.sum(&:net_revenue_cents),
        rows: rows
      )
    end

    private

    attr_reader :scope

    def line_scope
      PosTransactionLine
        .joins(:pos_transaction)
        .merge(scope.transactions)
        .includes(:pos_transaction, :product_variant)
        .order("pos_transactions.business_date", "pos_transactions.transaction_number", :line_number)
    end

    def signed_extended_price_cents(line)
      line.quantity.negative? ? -line.extended_price_cents : line.extended_price_cents
    end

    def build_row(line)
      Row.new(
        pos_transaction_line_id: line.id,
        transaction_number: line.pos_transaction.transaction_number,
        business_date: line.pos_transaction.business_date,
        sku: line.variant_sku_snapshot || line.product_variant&.sku,
        variant_name: line.variant_name_snapshot || line.product_variant&.name,
        quantity: line.quantity,
        net_revenue_cents: signed_extended_price_cents(line),
        total_cogs_cents: line.total_cogs_cents,
        cogs_estimated: line.cogs_estimated?,
        revenue_treatment: line.revenue_treatment
      )
    end
  end
end
