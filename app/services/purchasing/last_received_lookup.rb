# frozen_string_literal: true

module Purchasing
  class LastReceivedLookup
    LastReceived = Data.define(:received_at, :quantity_accepted, :unit_cost_cents, :receipt, :vendor)

    def self.for_variant(store:, variant:)
      for_variants(store: store, variant_ids: [ variant.id ]).fetch(variant.id, nil)
    end

    def self.for_variants(store:, variant_ids:)
      new(store: store, variant_ids: variant_ids).lookup
    end

    def initialize(store:, variant_ids:)
      @store = store
      @variant_ids = Array(variant_ids).compact.uniq
    end

    def lookup
      return {} if store.blank? || variant_ids.empty?

      lines = ReceiptLine
        .joins(receipt: :vendor)
        .includes(receipt: :vendor)
        .where(
          product_variant_id: variant_ids,
          receipts: { store_id: store.id, status: "posted" }
        )
        .where("receipt_lines.quantity_accepted > 0")
        .order("receipts.posted_at DESC")

      lines.each_with_object({}) do |line, results|
        variant_id = line.product_variant_id
        next if results.key?(variant_id)

        results[variant_id] = LastReceived.new(
          received_at: line.receipt.posted_at,
          quantity_accepted: line.quantity_accepted,
          unit_cost_cents: line.unit_cost_cents,
          receipt: line.receipt,
          vendor: line.receipt.vendor
        )
      end
    end

    private

    attr_reader :store, :variant_ids
  end
end
