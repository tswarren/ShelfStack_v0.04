# frozen_string_literal: true

module Purchasing
  class BuildPurchaseOrder
    class BuildError < StandardError; end

    def self.call(store:, vendor:, created_by_user:, manual_lines: [], notes: nil, line_quantities: {})
      new(
        store:,
        vendor:,
        created_by_user:,
        manual_lines:,
        notes:,
        line_quantities:
      ).call
    end

    def initialize(store:, vendor:, created_by_user:, manual_lines: [], notes: nil, line_quantities: {})
      @store = store
      @vendor = vendor
      @created_by_user = created_by_user
      @manual_lines = Array(manual_lines)
      @notes = notes
      @line_quantities = line_quantities.stringify_keys
    end

    def call
      raise BuildError, "Vendor is required" if vendor.blank?
      raise BuildError, "At least one line is required" if manual_lines.empty?

      purchase_order = nil
      PurchaseOrder.transaction do
        purchase_order = PurchaseOrder.create!(
          store: store,
          vendor: vendor,
          status: "draft",
          notes: notes
        )

        manual_lines.each do |line_attrs|
          variant = ProductVariant.find(line_attrs[:product_variant_id] || line_attrs["product_variant_id"])
          validate_po_eligibility!(variant, label: variant.sku)

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
            "line_count" => purchase_order.purchase_order_lines.size
          }
        )
      end

      purchase_order
    end

    private

    attr_reader :store, :vendor, :created_by_user, :manual_lines, :notes, :line_quantities

    def validate_po_eligibility!(variant, label:)
      result = OrderEligibilityResolver.call(product_variant: variant, vendor: vendor, context: :purchase_order)
      return unless result.blocking?

      messages = result.blocking_reasons.map(&:message).join("; ")
      raise BuildError, "#{label}: #{messages}"
    end
  end
end
