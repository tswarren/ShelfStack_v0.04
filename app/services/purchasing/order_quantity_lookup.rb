# frozen_string_literal: true

module Purchasing
  class OrderQuantityLookup
    Result = Data.define(:on_order, :pending, :reserved_incoming, :on_order_available)

    ON_ORDER_PO_STATUSES = %w[submitted partially_received].freeze
    PENDING_PO_STATUSES = %w[draft].freeze
    ACTIVE_PO_STATUSES = (ON_ORDER_PO_STATUSES + PENDING_PO_STATUSES).freeze
    OPEN_LINE_STATUSES = %w[open partially_received backordered].freeze

    def self.for_variant(store:, variant:)
      for_variants(store: store, variant_ids: [ variant.id ]).fetch(variant.id) { zero_result }
    end

    def self.for_variants(store:, variant_ids:)
      new(store:, variant_ids:).lookup
    end

    def initialize(store:, variant_ids:)
      @store = store
      @variant_ids = Array(variant_ids).compact.uniq
    end

    def lookup
      return {} if store.blank? || variant_ids.empty?

      rows = PurchaseOrderLine
        .joins(:purchase_order)
        .where(purchase_orders: { store_id: store.id, status: ACTIVE_PO_STATUSES })
        .where(product_variant_id: variant_ids)
        .where(status: OPEN_LINE_STATUSES)
        .group(:product_variant_id, "purchase_orders.status")
        .sum(remainder_sql)

      variant_ids.index_with { zero_result }.tap do |results|
        rows.each do |(variant_id, po_status), quantity|
          bucket = results[variant_id]
          if ON_ORDER_PO_STATUSES.include?(po_status)
            results[variant_id] = bucket.with(on_order: bucket.on_order + quantity)
          elsif PENDING_PO_STATUSES.include?(po_status)
            results[variant_id] = bucket.with(pending: bucket.pending + quantity)
          end
        end
        apply_incoming_reserves!(results)
      end
    end

    def self.zero_result
      Result.new(on_order: 0, pending: 0, reserved_incoming: 0, on_order_available: 0)
    end

    private

    attr_reader :store, :variant_ids

    def zero_result
      self.class.zero_result
    end

    def remainder_sql
      Arel.sql("GREATEST(purchase_order_lines.quantity_ordered - purchase_order_lines.quantity_received, 0)")
    end

    def apply_incoming_reserves!(results)
      incoming = InventoryReservation.active_incoming
                                       .where(store: store, product_variant_id: variant_ids)
                                       .group(:product_variant_id)
                                       .sum("quantity_reserved - quantity_fulfilled - quantity_released")

      results.each do |variant_id, bucket|
        reserved = incoming[variant_id] || 0
        results[variant_id] = bucket.with(
          reserved_incoming: reserved,
          on_order_available: [ bucket.on_order - reserved, 0 ].max
        )
      end
    end
  end
end
