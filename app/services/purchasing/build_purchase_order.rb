# frozen_string_literal: true

module Purchasing
  class BuildPurchaseOrder
    class BuildError < StandardError; end

    def self.call(store:, vendor:, created_by_user:, purchase_request_lines: [], manual_lines: [], notes: nil)
      new(
        store:,
        vendor:,
        created_by_user:,
        purchase_request_lines:,
        manual_lines:,
        notes:
      ).call
    end

    def initialize(store:, vendor:, created_by_user:, purchase_request_lines: [], manual_lines: [], notes: nil)
      @store = store
      @vendor = vendor
      @created_by_user = created_by_user
      @purchase_request_lines = Array(purchase_request_lines)
      @manual_lines = Array(manual_lines)
      @notes = notes
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

      purchase_order
    end

    private

    attr_reader :store, :vendor, :created_by_user, :purchase_request_lines, :manual_lines, :notes

    def add_line_from_request!(purchase_order, request_line)
      variant = request_line.product_variant
      sourcing = SourcingLookup.for(variant: variant, vendor: vendor)

      purchase_order.purchase_order_lines.create!(
        product_variant: variant,
        vendor: vendor,
        product_variant_vendor: sourcing.product_variant_vendor,
        quantity_ordered: request_line.requested_quantity,
        quantity_received: 0,
        status: "open"
      )

      request_line.update!(status: "added_to_po")
    end
  end
end
