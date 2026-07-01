# frozen_string_literal: true

module Items
  class ItemOperationsPresenter
    include Rails.application.routes.url_helpers

    Metric = Data.define(:label, :value, :class_name)
    Action = Data.define(:label, :url, :permission_key)
    CustomerDemandAction = Data.define(:label, :drawer_key, :permission_key)
    AvailabilityContext = Data.define(:available, :on_hand, :reserved)
    VariantRow = Data.define(
      :variant,
      :on_hand,
      :available,
      :reserved,
      :on_order_available,
      :ready_for_pickup_qty,
      :open_tbo,
      :pending_po,
      :on_order,
      :last_received,
      :preferred_vendor_name,
      :preferred_vendor_source,
      :vendor_item_number,
      :returnability_status,
      :actions,
      :demand_actions,
      :availability_context
    )

    def initialize(item:, store:, user:)
      @item = item
      @store = store
      @user = user
    end

    def inventory_visible?
      return false unless store.present? && user.present?

      Authorization.allowed?(user: user, permission_key: "inventory.access", store: store) &&
        Authorization.allowed?(user: user, permission_key: "inventory.balances.view", store: store)
    end

    def variant_rows
      @variant_rows ||= build_variant_rows
    end

    def rollup_metrics
      return [] unless inventory_visible? && item.product.present?

      rows = variant_rows
      last_received = rows.filter_map(&:last_received).max_by(&:received_at)

      [
        Metric.new(label: "On hand", value: rows.sum { |row| row.on_hand || 0 }, class_name: "ss-num"),
        Metric.new(label: "Available", value: rows.sum { |row| row.available || 0 }, class_name: "ss-num"),
        Metric.new(label: "Reserved", value: rows.sum { |row| row.reserved || 0 }, class_name: "ss-num"),
        Metric.new(label: "TBO", value: rows.sum(&:open_tbo), class_name: "ss-num"),
        Metric.new(label: "Pending PO", value: rows.sum { |row| row.pending_po || 0 }, class_name: "ss-num"),
        Metric.new(label: "On order", value: rows.sum { |row| row.on_order || 0 }, class_name: "ss-num"),
        Metric.new(
          label: "Last received",
          value: last_received ? helpers.l(last_received.received_at.to_date) : "—",
          class_name: nil
        )
      ]
    end

    def header_actions
      actions = []
      eligible_variant = item.variants.find { |variant| inventory_eligible?(variant) }

      if eligible_variant && allowed?("orders.purchase_requests.create")
        actions << Action.new(
          label: "Mark TBO",
          url: new_orders_purchase_request_path(product_variant_id: eligible_variant.id),
          permission_key: "orders.purchase_requests.create"
        )
      end

      if eligible_variant && allowed?("orders.purchase_orders.create")
        actions << Action.new(
          label: "Add to PO",
          url: from_tbo_orders_purchase_orders_path,
          permission_key: "orders.purchase_orders.create"
        )
      end

      receivable_po = receivable_purchase_order_for_item
      if receivable_po && allowed?("orders.receipts.create")
        actions << Action.new(
          label: "Receive",
          url: receive_orders_purchase_order_path(receivable_po),
          permission_key: "orders.receipts.create"
        )
      end

      if eligible_variant && allowed?("orders.returns_to_vendor.create")
        actions << Action.new(
          label: "RTV",
          url: new_orders_returns_to_vendor_path,
          permission_key: "orders.returns_to_vendor.create"
        )
      end

      edit_path = edit_item_path
      if edit_path.present?
        actions << Action.new(label: "Edit Item", url: edit_path, permission_key: nil)
      end

      actions.select { |action| allowed_action?(action) }
    end

    def receivable_purchase_order_for_item
      return nil unless item.product.present?

      PurchaseOrder
        .joins(:purchase_order_lines)
        .where(store: store, status: %w[submitted partially_received])
        .where(purchase_order_lines: {
          product_variant_id: item.variants.map(&:id),
          status: Purchasing::OrderQuantityLookup::OPEN_LINE_STATUSES
        })
        .distinct
        .order(:id)
        .first
    end

    def customer_demand_visible?
      return false unless store.present? && user.present?

      Authorization.allowed?(user: user, permission_key: "customer_requests.access", store: store)
    end

    def availability_context(variant)
      return nil unless inventory_eligible?(variant)

      row = operational_snapshot.rows[variant.id]
      return nil if row.blank?

      AvailabilityContext.new(
        available: row.available || 0,
        on_hand: row.on_hand || 0,
        reserved: row.reserved || 0
      )
    end

    def variant_customer_demand_actions(variant)
      return [] unless customer_demand_visible?

      actions = []
      if allowed?("customer_requests.create") && allowed?("inventory_reservations.create")
        actions << CustomerDemandAction.new(
          label: "Hold for customer",
          drawer_key: "hold",
          permission_key: "inventory_reservations.create"
        )
      end
      if allowed?("customer_requests.create") && allowed?("special_orders.create")
        actions << CustomerDemandAction.new(
          label: "Special order",
          drawer_key: "special_order",
          permission_key: "special_orders.create"
        )
      end
      if allowed?("customer_requests.create")
        actions << CustomerDemandAction.new(
          label: "Notify customer",
          drawer_key: "notify",
          permission_key: "customer_requests.create"
        )
      end
      actions
    end

    def variant_actions(variant)
      actions = []
      if inventory_eligible?(variant) && allowed?("orders.purchase_requests.create")
        actions << Action.new(
          label: "TBO",
          url: new_orders_purchase_request_path(product_variant_id: variant.id),
          permission_key: "orders.purchase_requests.create"
        )
      end
      if inventory_eligible?(variant) && allowed?("orders.purchase_orders.create")
        vendor_id = suggested_vendor_id(variant)
        actions << Action.new(
          label: "Order",
          url: from_tbo_orders_purchase_orders_path(vendor_id.present? ? { vendor_id: vendor_id } : {}),
          permission_key: "orders.purchase_orders.create"
        )
      end
      receivable_po = receivable_purchase_order_for(variant)
      if receivable_po && allowed?("orders.receipts.create")
        actions << Action.new(
          label: "Receive",
          url: receive_orders_purchase_order_path(receivable_po),
          permission_key: "orders.receipts.create"
        )
      end
      if inventory_eligible?(variant) && allowed?("orders.returns_to_vendor.create")
        actions << Action.new(
          label: "RTV",
          url: new_orders_returns_to_vendor_path,
          permission_key: "orders.returns_to_vendor.create"
        )
      end
      actions
    end

    private

    attr_reader :item, :store, :user

    def build_variant_rows
      return [] unless item.product.present?

      variants = item.variants.to_a
      return [] if variants.empty?

      variants.map do |variant|
        row = operational_snapshot.rows[variant.id]
        next if row.blank?

        suggested = row.suggested_vendor
        vendor = suggested.vendor

        VariantRow.new(
          variant: variant,
          on_hand: row.on_hand,
          available: row.available,
          reserved: row.reserved,
          on_order_available: row.on_order_available,
          ready_for_pickup_qty: row.ready_for_pickup_qty,
          open_tbo: row.open_tbo,
          pending_po: row.pending_po,
          on_order: row.on_order,
          last_received: row.last_received,
          preferred_vendor_name: vendor&.name,
          preferred_vendor_source: suggested.source,
          vendor_item_number: row.vendor_item_number,
          returnability_status: row.returnability_status,
          actions: variant_actions(variant),
          demand_actions: variant_customer_demand_actions(variant),
          availability_context: availability_context(variant)
        )
      end.compact
    end

    def operational_snapshot
      @operational_snapshot ||= VariantOperationalSnapshot.for_variants(
        store: store,
        variants: item.variants.to_a,
        user: user,
        item: item
      )
    end

    def receivable_purchase_order_for(variant)
      PurchaseOrder
        .joins(:purchase_order_lines)
        .where(store: store, status: %w[submitted partially_received])
        .where(purchase_order_lines: {
          product_variant_id: variant.id,
          status: Purchasing::OrderQuantityLookup::OPEN_LINE_STATUSES
        })
        .distinct
        .first
    end

    def suggested_vendor_id(variant)
      operational_snapshot.suggested_vendors.fetch(variant.id) { Purchasing::SuggestedVendorResolver.for_variant(variant) }.vendor&.id
    end

    def edit_item_path
      if item.catalog_item.present? && allowed?("items.catalog_items.update")
        edit_items_catalog_item_path(item.catalog_item, return_to: "item")
      elsif item.product&.metadata_fused? && allowed?("items.products.update")
        edit_metadata_items_product_path(item.product, return_to: "item")
      elsif item.product.present? && allowed?("items.products.update")
        edit_items_product_path(item.product, return_to: "item")
      end
    end

    def inventory_eligible?(variant)
      Inventory::Eligibility.eligible?(variant)
    end

    def allowed?(permission_key)
      Authorization.allowed?(user: user, permission_key: permission_key, store: store)
    end

    def allowed_action?(action)
      action.permission_key.blank? || allowed?(action.permission_key)
    end

    def helpers
      ApplicationController.helpers
    end
  end
end
