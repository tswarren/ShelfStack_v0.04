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
        { label: "Open TBO", value: open_manual_tbo_count },
        { label: "Open PO lines", value: open_purchase_order_lines.size },
        { label: "Recent receipts", value: recent_receipt_lines.size },
        { label: "RTV lines", value: recent_rtv_lines.size }
      ]
      return base unless customer_demand_visible?

      base + [
        { label: "Open demand", value: open_demand_count },
        { label: "Active holds", value: active_on_hand_allocation_count },
        { label: "Special orders", value: open_special_order_count }
      ]
    end

    def customer_demand_visible?
      return false unless store.present? && user.present?

      Authorization.allowed?(user: user, permission_key: "demand.access", store: store)
    end

    def open_customer_request_lines
      []
    end

    def variant_scoped_customer_request_lines
      []
    end

    def active_holds
      []
    end

    def incoming_reserves
      []
    end

    def open_manual_tbo_demand_lines
      []
    end

    def open_special_order_demand_lines
      []
    end

    def variant_scoped_manual_tbo_demand_lines
      return open_manual_tbo_demand_lines if highlight_variant.blank?

      open_manual_tbo_demand_lines.select { |line| line.product_variant_id == highlight_variant.id }
    end

    def variant_scoped_special_order_demand_lines
      return open_special_order_demand_lines if highlight_variant.blank?

      open_special_order_demand_lines.select { |line| line.product_variant_id == highlight_variant.id }
    end

    def variant_scoped_active_holds
      return active_holds if highlight_variant.blank?

      active_holds.select { |allocation| allocation.product_variant_id == highlight_variant.id }
    end

    def variant_scoped_incoming_reserves
      return incoming_reserves if highlight_variant.blank?

      incoming_reserves.select { |allocation| allocation.product_variant_id == highlight_variant.id }
    end

    # Legacy empty stubs — demand lists wire through DemandLine queries in future slices.
    alias_method :open_purchase_request_lines, :open_manual_tbo_demand_lines
    alias_method :open_special_orders, :open_special_order_demand_lines
    alias_method :variant_scoped_purchase_request_lines, :variant_scoped_manual_tbo_demand_lines
    alias_method :variant_scoped_special_orders, :variant_scoped_special_order_demand_lines

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

    def open_demand_count
      @open_demand_count ||= DemandLine.where(store: store, product_variant_id: variant_ids)
                                       .where.not(status: DemandLine::TERMINAL_STATUSES)
                                       .count
    end

    def open_manual_tbo_count
      @open_manual_tbo_count ||= DemandLine.where(store: store, product_variant_id: variant_ids, capture_intent: "manual_tbo")
                                           .where.not(status: DemandLine::TERMINAL_STATUSES)
                                           .count
    end

    def open_special_order_count
      @open_special_order_count ||= DemandLine.where(store: store, product_variant_id: variant_ids, capture_intent: "special_order")
                                              .where.not(status: DemandLine::TERMINAL_STATUSES)
                                              .count
    end

    def active_on_hand_allocation_count
      @active_on_hand_allocation_count ||= DemandAllocation.active_allocations
                                                           .on_hand_kind
                                                           .where(store: store, product_variant_id: variant_ids)
                                                           .count
    end
  end
end
