# frozen_string_literal: true

module Items
  class ItemOperationsTabPresenter
    include Rails.application.routes.url_helpers

    def initialize(item:, store:, user:, highlight_variant: nil)
      @item = item
      @store = store
      @user = user
      @highlight_variant = highlight_variant
    end

    attr_reader :highlight_variant

    def metrics
      [
        { label: "Open TBO", value: open_purchase_request_lines.size },
        { label: "Open PO lines", value: open_purchase_order_lines.size },
        { label: "Recent receipts", value: recent_receipt_lines.size },
        { label: "RTV lines", value: recent_rtv_lines.size }
      ]
    end

    def open_purchase_request_lines
      @open_purchase_request_lines ||= scoped_purchase_request_lines.to_a
    end

    def open_purchase_order_lines
      @open_purchase_order_lines ||= PurchaseOrderLine
        .joins(:purchase_order)
        .includes(:purchase_order, :product_variant)
        .where(
          product_variant_id: variant_ids,
          purchase_orders: { store_id: store.id, status: Purchasing::OrderQuantityLookup::ACTIVE_PO_STATUSES },
          status: Purchasing::OrderQuantityLookup::OPEN_LINE_STATUSES
        )
        .order("purchase_orders.created_at DESC, purchase_order_lines.line_number ASC")
        .to_a
    end

    def recent_receipt_lines
      @recent_receipt_lines ||= ReceiptLine
        .joins(:receipt)
        .includes(:receipt, :product_variant, receipt: :vendor)
        .where(product_variant_id: variant_ids, receipts: { store_id: store.id, status: %w[draft posted] })
        .order("receipts.created_at DESC, receipt_lines.line_number ASC")
        .limit(20)
        .to_a
    end

    def recent_rtv_lines
      @recent_rtv_lines ||= ReturnToVendorLine
        .joins(:return_to_vendor)
        .includes(:return_to_vendor, :product_variant, return_to_vendor: :vendor)
        .where(product_variant_id: variant_ids, returns_to_vendor: { store_id: store.id })
        .order("returns_to_vendor.created_at DESC, return_to_vendor_lines.line_number ASC")
        .limit(20)
        .to_a
    end

    def variant_scoped_purchase_request_lines
      return open_purchase_request_lines if highlight_variant.blank?

      open_purchase_request_lines.select { |line| line.product_variant_id == highlight_variant.id }
    end

    def variant_scoped_purchase_order_lines
      return open_purchase_order_lines if highlight_variant.blank?

      open_purchase_order_lines.select { |line| line.product_variant_id == highlight_variant.id }
    end

    def variant_scoped_receipt_lines
      return recent_receipt_lines if highlight_variant.blank?

      recent_receipt_lines.select { |line| line.product_variant_id == highlight_variant.id }
    end

    def variant_scoped_rtv_lines
      return recent_rtv_lines if highlight_variant.blank?

      recent_rtv_lines.select { |line| line.product_variant_id == highlight_variant.id }
    end

    private

    attr_reader :item, :store, :user

    def variant_ids
      @variant_ids ||= item.variants.map(&:id)
    end

    def scoped_purchase_request_lines
      return PurchaseRequestLine.none if variant_ids.empty?

      PurchaseRequestLine
        .buildable_for_store(store)
        .includes(:purchase_request, :product_variant)
        .where(product_variant_id: variant_ids)
        .order("purchase_requests.created_at DESC, purchase_request_lines.line_number ASC")
    end
  end
end
