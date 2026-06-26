# frozen_string_literal: true

module Items
  class ReceivingHistoryLookup
    ReceiptRow = Data.define(
      :received_at,
      :variant_id,
      :quantity_accepted,
      :unit_cost_cents,
      :receipt,
      :vendor,
      :variant_sku,
      :purchase_order
    )

    def self.for_variants(store:, variant_ids:, limit: 10)
      new(store:, variant_ids:, limit:).rows
    end

    def initialize(store:, variant_ids:, limit: 10)
      @store = store
      @variant_ids = Array(variant_ids).compact.uniq
      @limit = limit
    end

    def rows
      return [] if store.blank? || variant_ids.empty?

      ReceiptLine
        .joins(receipt: :vendor)
        .includes(receipt: [ :vendor, :purchase_order ], product_variant: nil)
        .where(
          product_variant_id: variant_ids,
          receipts: { store_id: store.id, status: "posted" }
        )
        .where("receipt_lines.quantity_accepted > 0")
        .order(Arel.sql("COALESCE(receipts.posted_at, receipts.created_at) DESC, receipt_lines.line_number ASC"))
        .limit(limit)
        .map { |line| to_row(line) }
    end

    private

    attr_reader :store, :variant_ids, :limit

    def to_row(line)
      receipt = line.receipt
      ReceiptRow.new(
        received_at: receipt.posted_at || receipt.created_at,
        variant_id: line.product_variant_id,
        quantity_accepted: line.quantity_accepted,
        unit_cost_cents: line.unit_cost_cents,
        receipt: receipt,
        vendor: receipt.vendor,
        variant_sku: line.product_variant&.sku,
        purchase_order: receipt.purchase_order
      )
    end
  end
end
