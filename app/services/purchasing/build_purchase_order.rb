# frozen_string_literal: true

module Purchasing
  class BuildPurchaseOrder
    class BuildError < StandardError; end

    def self.call(store:, vendor:, created_by_user:, purchase_request_lines: [], manual_lines: [], notes: nil, line_quantities: {})
      new(
        store:,
        vendor:,
        created_by_user:,
        purchase_request_lines:,
        manual_lines:,
        notes:,
        line_quantities:
      ).call
    end

    def initialize(store:, vendor:, created_by_user:, purchase_request_lines: [], manual_lines: [], notes: nil, line_quantities: {})
      @store = store
      @vendor = vendor
      @created_by_user = created_by_user
      @purchase_request_lines = Array(purchase_request_lines)
      @manual_lines = Array(manual_lines)
      @notes = notes
      @line_quantities = line_quantities.stringify_keys
    end

    def call
      raise BuildError, "Vendor is required" if vendor.blank?
      raise BuildError, "At least one line is required" if purchase_request_lines.empty? && manual_lines.empty?

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

    attr_reader :store, :vendor, :created_by_user, :purchase_request_lines, :manual_lines, :notes, :line_quantities

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
