# frozen_string_literal: true

module Items
  class SalesHistoryLookup
    SalesRow = Data.define(:sold_at, :variant_id, :quantity, :net_sales_cents, :transaction, :variant_sku, :variant_name)

    Rollup = Data.define(:units_sold, :net_sales_cents)

    def self.for_variants(store:, variant_ids:, limit: 10)
      new(store:, variant_ids:, limit:).rows
    end

    def self.last_sold_at_for_variants(store:, variant_ids:)
      new(store:, variant_ids:).last_sold_at_by_variant
    end

    def self.rollup_for_variants(store:, variant_ids:, days: [ 30, 90 ])
      new(store:, variant_ids:, days:).rollups_by_variant
    end

    def initialize(store:, variant_ids:, limit: 10, days: [ 30, 90 ])
      @store = store
      @variant_ids = Array(variant_ids).compact.uniq
      @limit = limit
      @days = Array(days)
    end

    def rows
      return [] if store.blank? || variant_ids.empty?

      scoped_lines
        .order("pos_transactions.completed_at DESC, pos_transaction_lines.line_number ASC")
        .limit(limit)
        .map { |line| to_row(line) }
    end

    def last_sold_at_by_variant
      return {} if store.blank? || variant_ids.empty?

      scoped_lines
        .where("pos_transaction_lines.quantity > 0")
        .group(:product_variant_id)
        .maximum("pos_transactions.completed_at")
    end

    def rollups_by_variant
      return {} if store.blank? || variant_ids.empty?

      rollups = variant_ids.index_with do |_variant_id|
        days.index_with { |_day_count| Rollup.new(units_sold: 0, net_sales_cents: 0) }
      end

      days.each do |day_count|
        since = day_count.days.ago
        window_scope = scoped_lines.where("pos_transactions.completed_at >= ?", since)
        units_by_variant = window_scope.group(:product_variant_id).sum(:quantity)
        net_by_variant = window_scope.group(:product_variant_id).sum(net_sales_sql)

        variant_ids.each do |variant_id|
          rollups[variant_id][day_count] = Rollup.new(
            units_sold: units_by_variant.fetch(variant_id, 0),
            net_sales_cents: net_by_variant.fetch(variant_id, 0)
          )
        end
      end

      rollups
    end

    private

    attr_reader :store, :variant_ids, :limit, :days

    def scoped_lines
      PosTransactionLine
        .joins(:pos_transaction)
        .includes(:pos_transaction, :product_variant)
        .where(
          product_variant_id: variant_ids,
          pos_transactions: {
            store_id: store.id,
            status: "completed"
          }
        )
        .where(pos_transactions: { voided_at: nil })
        .where.not(line_type: %w[gift_card_sale])
    end

    def to_row(line)
      transaction = line.pos_transaction
      SalesRow.new(
        sold_at: transaction.completed_at,
        variant_id: line.product_variant_id,
        quantity: line.quantity,
        net_sales_cents: net_sales_cents(line),
        transaction: transaction,
        variant_sku: line.variant_sku_snapshot.presence || line.product_variant&.sku,
        variant_name: line.variant_name_snapshot.presence || line.product_variant&.name
      )
    end

    def net_sales_cents(line)
      line.extended_price_cents - line.line_discount_cents - line.transaction_discount_cents
    end

    def net_sales_sql
      Arel.sql("pos_transaction_lines.extended_price_cents - pos_transaction_lines.line_discount_cents - pos_transaction_lines.transaction_discount_cents")
    end
  end
end
