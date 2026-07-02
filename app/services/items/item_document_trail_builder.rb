# frozen_string_literal: true

module Items
  class ItemDocumentTrailBuilder
    include Rails.application.routes.url_helpers

    TrailNode = Data.define(:label, :href, :meta, :occurred_at)

    def self.for(item:, store:)
      new(item:, store:).nodes
    end

    def initialize(item:, store:)
      @item = item
      @store = store
    end

    def nodes
      variant_ids = item.variants.map(&:id)
      return [] if variant_ids.empty?

      events = []
      events.concat(purchase_order_events(variant_ids))
      events.concat(receipt_events(variant_ids))
      events.concat(rtv_events(variant_ids))
      events.sort_by(&:occurred_at).reverse
    end

    private

    attr_reader :item, :store

    def purchase_request_events(variant_ids)
      []
    end

    def purchase_order_events(variant_ids)
      PurchaseOrderLine
        .joins(:purchase_order)
        .includes(:purchase_order, :product_variant)
        .where(product_variant_id: variant_ids, purchase_orders: { store_id: store.id })
        .map do |line|
          po = line.purchase_order
          TrailNode.new(
            label: "PO ##{po.id} line #{line.line_number}",
            href: orders_purchase_order_path(po),
            meta: "#{line.product_variant.sku}, ordered #{line.quantity_ordered}, #{po.status}",
            occurred_at: po.submitted_at || po.created_at
          )
        end
    end

    def receipt_events(variant_ids)
      ReceiptLine
        .joins(:receipt)
        .includes(:receipt, :product_variant)
        .where(product_variant_id: variant_ids, receipts: { store_id: store.id, status: "posted" })
        .map do |line|
          receipt = line.receipt
          TrailNode.new(
            label: "Receipt ##{receipt.id} line #{line.line_number}",
            href: orders_receipt_path(receipt),
            meta: "#{line.product_variant.sku}, accepted #{line.quantity_accepted}",
            occurred_at: receipt.posted_at || receipt.updated_at
          )
        end
    end

    def rtv_events(variant_ids)
      ReturnToVendorLine
        .joins(:return_to_vendor)
        .includes(:return_to_vendor, :product_variant)
        .where(product_variant_id: variant_ids, returns_to_vendor: { store_id: store.id, status: "posted" })
        .map do |line|
          rtv = line.return_to_vendor
          TrailNode.new(
            label: "RTV ##{rtv.id} line #{line.line_number}",
            href: orders_returns_to_vendor_path(rtv),
            meta: "#{line.product_variant.sku}, qty #{line.quantity}",
            occurred_at: rtv.posted_at || rtv.updated_at
          )
        end
    end
  end
end
