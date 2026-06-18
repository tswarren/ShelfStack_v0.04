# frozen_string_literal: true

module Items
  class ItemOperationsPresenter
    include Rails.application.routes.url_helpers

    Metric = Data.define(:label, :value, :class_name)
    Action = Data.define(:label, :url, :permission_key)
    VariantRow = Data.define(
      :variant,
      :on_hand,
      :available,
      :open_tbo,
      :pending_po,
      :on_order,
      :last_received,
      :preferred_vendor_name,
      :vendor_item_number,
      :returnability_status,
      :actions
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

      if allowed?("orders.purchase_orders.create")
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

    def variant_actions(variant)
      actions = []
      if inventory_eligible?(variant) && allowed?("orders.purchase_requests.create")
        actions << Action.new(
          label: "TBO",
          url: new_orders_purchase_request_path(product_variant_id: variant.id),
          permission_key: "orders.purchase_requests.create"
        )
      end
      if allowed?("orders.purchase_orders.create")
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

      variant_ids = variants.map(&:id)
      balances = InventoryBalance.where(store: store, product_variant_id: variant_ids).index_by(&:product_variant_id)
      order_quantities = Purchasing::OrderQuantityLookup.for_variants(store: store, variant_ids: variant_ids)
      open_tbo = open_tbo_quantities_for(variant_ids)
      last_received = Purchasing::LastReceivedLookup.for_variants(store: store, variant_ids: variant_ids)
      suggested_vendors = Purchasing::SuggestedVendorResolver.for_variants(variant_ids)

      variants.map do |variant|
        eligible = inventory_eligible?(variant)
        balance = balances[variant.id]
        order_qty = order_quantities.fetch(variant.id) { Purchasing::OrderQuantityLookup.zero_result }
        suggested = suggested_vendors.fetch(variant.id) { Purchasing::SuggestedVendorResolver.for_variant(variant) }
        vendor = suggested.vendor
        sourcing = vendor.present? ? Purchasing::SourcingLookup.for(variant: variant, vendor: vendor) : nil

        VariantRow.new(
          variant: variant,
          on_hand: eligible ? (balance&.quantity_on_hand || 0) : nil,
          available: eligible ? Inventory::Availability.available(store: store, variant: variant) : nil,
          open_tbo: open_tbo.fetch(variant.id, 0),
          pending_po: eligible ? order_qty.pending : nil,
          on_order: eligible ? order_qty.on_order : nil,
          last_received: last_received[variant.id],
          preferred_vendor_name: vendor&.name,
          vendor_item_number: sourcing&.vendor_item_number,
          returnability_status: vendor.present? ? Purchasing::ReturnabilityResolver.resolve(variant: variant, vendor: vendor) : nil,
          actions: variant_actions(variant)
        )
      end
    end

    def open_tbo_quantities_for(variant_ids)
      PurchaseRequestLine
        .buildable_for_store(store)
        .where(product_variant_id: variant_ids)
        .group(:product_variant_id)
        .sum(:requested_quantity)
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

    def suggested_vendor_id(variant)
      Purchasing::SuggestedVendorResolver.for_variant(variant).vendor&.id
    end

    def edit_item_path
      if item.catalog_item.present? && allowed?("items.catalog_items.update")
        edit_items_catalog_item_path(item.catalog_item, return_to: "item")
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
