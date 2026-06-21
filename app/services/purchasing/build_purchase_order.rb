# frozen_string_literal: true

module Purchasing
  class BuildPurchaseOrder
    class BuildError < StandardError; end

    def self.call(store:, vendor:, created_by_user:, purchase_request_lines: [], manual_lines: [], special_orders: [],
                  notes: nil, line_quantities: {})
      new(
        store:,
        vendor:,
        created_by_user:,
        purchase_request_lines:,
        manual_lines:,
        special_orders:,
        notes:,
        line_quantities:
      ).call
    end

    def initialize(store:, vendor:, created_by_user:, purchase_request_lines: [], manual_lines: [], special_orders: [],
                   notes: nil, line_quantities: {})
      @store = store
      @vendor = vendor
      @created_by_user = created_by_user
      @purchase_request_lines = Array(purchase_request_lines)
      @manual_lines = Array(manual_lines)
      @special_orders = Array(special_orders)
      @notes = notes
      @line_quantities = line_quantities.stringify_keys
    end

    def call
      raise BuildError, "Vendor is required" if vendor.blank?
      if purchase_request_lines.empty? && manual_lines.empty? && special_orders.empty?
        raise BuildError, "At least one line is required"
      end

      purchase_order = nil
      PurchaseOrder.transaction do
        purchase_order = PurchaseOrder.create!(
          store: store,
          vendor: vendor,
          status: "draft",
          notes: notes
        )

        purchase_request_lines.each do |request_line|
          add_line_from_request!(purchase_order, request_line)
        end

        manual_lines.each do |line_attrs|
          purchase_order.purchase_order_lines.create!(
            {
              vendor: vendor,
              quantity_received: 0,
              status: "open"
            }.merge(line_attrs)
          )
        end

        special_orders.each do |special_order|
          add_line_from_special_order!(purchase_order, special_order)
        end

        AuditEvents.record!(
          actor: created_by_user,
          event_name: "purchase_order.created",
          auditable: purchase_order,
          details: {
            "from_purchase_request_lines" => purchase_request_lines.map(&:id),
            "line_count" => purchase_order.purchase_order_lines.size
          }
        )
      end

      PurchaseRequest.refresh_statuses_for_lines!(purchase_request_lines)

      purchase_order
    end

    private

    attr_reader :store, :vendor, :created_by_user, :purchase_request_lines, :manual_lines, :special_orders, :notes, :line_quantities

    def add_line_from_special_order!(purchase_order, special_order)
      variant = special_order.product_variant
      qty = special_order.remaining_committed
      existing_line = purchase_order.purchase_order_lines.find_by(product_variant: variant, vendor: vendor)

      po_line = if existing_line
        existing_line.update!(quantity_ordered: existing_line.quantity_ordered + qty)
        existing_line
      else
        sourcing = SourcingLookup.for(variant: variant, vendor: vendor)
        purchase_order.purchase_order_lines.create!(
          product_variant: variant,
          vendor: vendor,
          product_variant_vendor: sourcing.product_variant_vendor,
          quantity_ordered: qty,
          quantity_received: 0,
          status: "open"
        )
      end

      SpecialOrders::AttachToPurchaseOrderLine.call!(
        special_order: special_order,
        purchase_order_line: po_line,
        quantity: qty,
        attached_by_user: created_by_user
      )
    end

    def add_line_from_request!(purchase_order, request_line)
      variant = request_line.product_variant
      sourcing = SourcingLookup.for(variant: variant, vendor: vendor)
      remaining = request_line.remaining_quantity
      quantity_ordered = resolved_quantity_for(request_line, remaining)

      purchase_order.purchase_order_lines.create!(
        product_variant: variant,
        vendor: vendor,
        product_variant_vendor: sourcing.product_variant_vendor,
        purchase_request_line: request_line,
        quantity_ordered: quantity_ordered,
        quantity_received: 0,
        status: "open"
      )

      request_line.update!(status: quantity_ordered >= remaining ? "added_to_po" : "partially_ordered")
    end

    def resolved_quantity_for(request_line, remaining)
      raw = line_quantities[request_line.id.to_s]
      quantity = raw.present? ? raw.to_i : remaining
      raise BuildError, "Order quantity must be at least 1 for TBO line ##{request_line.line_number}" if quantity < 1
      raise BuildError, "Order quantity cannot exceed remaining TBO quantity for line ##{request_line.line_number}" if quantity > remaining

      quantity
    end
  end
end
