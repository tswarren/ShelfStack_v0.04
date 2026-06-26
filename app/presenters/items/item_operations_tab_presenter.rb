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
      base = [
        { label: "Open TBO", value: open_purchase_request_lines.size },
        { label: "Open PO lines", value: open_purchase_order_lines.size },
        { label: "Recent receipts", value: recent_receipt_lines.size },
        { label: "RTV lines", value: recent_rtv_lines.size }
      ]
      return base unless customer_demand_visible?

      base + [
        { label: "Open requests", value: open_customer_request_lines.size },
        { label: "Active holds", value: active_holds.size },
        { label: "Special orders", value: open_special_orders.size }
      ]
    end

    def customer_demand_visible?
      return false unless store.present? && user.present?

      Authorization.allowed?(user: user, permission_key: "customer_requests.access", store: store)
    end

    def open_customer_request_lines
      @open_customer_request_lines ||= CustomerRequestLine.open_lines
                                                          .includes(:customer_request, :product_variant)
                                                          .joins(:customer_request)
                                                          .where(product_variant_id: variant_ids, customer_requests: { store_id: store.id })
                                                          .order("customer_requests.created_at DESC")
                                                          .to_a
    end

    def active_holds
      @active_holds ||= InventoryReservation.active_on_hand
                                              .includes(:customer, :product_variant, customer_request_line: :customer_request)
                                              .where(store: store, product_variant_id: variant_ids)
                                              .order(reserved_at: :desc)
                                              .to_a
    end

    def incoming_reserves
      @incoming_reserves ||= InventoryReservation.active_incoming
                                                   .includes(:customer, :product_variant, :special_order, customer_request_line: :customer_request)
                                                   .where(store: store, product_variant_id: variant_ids)
                                                   .order(reserved_at: :desc)
                                                   .to_a
    end

    def open_special_orders
      @open_special_orders ||= SpecialOrder.open_orders
                                           .includes(:customer, :product_variant, :customer_request_line)
                                           .where(store: store, product_variant_id: variant_ids)
                                           .order(created_at: :desc)
                                           .to_a
    end

    def variant_scoped_customer_request_lines
      return open_customer_request_lines if highlight_variant.blank?

      open_customer_request_lines.select { |line| line.product_variant_id == highlight_variant.id }
    end

    def variant_scoped_active_holds
      return active_holds if highlight_variant.blank?

      active_holds.select { |reservation| reservation.product_variant_id == highlight_variant.id }
    end

    def variant_scoped_incoming_reserves
      return incoming_reserves if highlight_variant.blank?

      incoming_reserves.select { |reservation| reservation.product_variant_id == highlight_variant.id }
    end

    def variant_scoped_special_orders
      return open_special_orders if highlight_variant.blank?

      open_special_orders.select { |order| order.product_variant_id == highlight_variant.id }
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

    def sales_visible?
      return false unless store.present? && user.present?

      Authorization.allowed?(user: user, permission_key: "pos.transactions.view", store: store)
    end

    def sales_history_rows
      @sales_history_rows ||= if sales_visible? && variant_ids.any?
        SalesHistoryLookup.for_variants(store: store, variant_ids: variant_ids, limit: 20)
      else
        []
      end
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
