# frozen_string_literal: true

module Purchasing
  class BuildReceiptFromPurchaseOrder
    class BuildError < StandardError; end

    RECEIVABLE_PO_STATUSES = %w[submitted partially_received].freeze
    OPEN_FOR_RECEIVE_LINE_STATUSES = %w[open partially_received backordered].freeze

    def self.call(purchase_order:, created_by_user:)
      new(purchase_order:, created_by_user:).call
    end

    def initialize(purchase_order:, created_by_user:)
      @purchase_order = purchase_order
      @created_by_user = created_by_user
    end

    def call
      raise BuildError, "Purchase order is not receivable" unless purchase_order.receivable?

      receipt = nil
      Receipt.transaction do
        receipt = Receipt.create!(
          store: purchase_order.store,
          vendor: purchase_order.vendor,
          purchase_order: purchase_order,
          receipt_type: "po_backed",
          status: "draft"
        )

        open_lines_for_receiving.each do |po_line|
          remainder = po_line.quantity_ordered - po_line.quantity_received
          next if remainder <= 0

          receipt.receipt_lines.create!(
            product_variant: po_line.product_variant,
            purchase_order_line: po_line,
            quantity_expected: remainder,
            quantity_received: remainder,
            quantity_accepted: remainder,
            quantity_rejected: 0,
            unit_list_price_cents: po_line.unit_list_price_cents,
            supplier_discount_bps: po_line.supplier_discount_bps,
            unit_cost_cents: po_line.unit_cost_cents
          )
        end

        raise BuildError, "No open lines to receive" if receipt.receipt_lines.empty?

        AuditEvents.record!(
          actor: created_by_user,
          event_name: "receipt.created",
          auditable: receipt,
          details: {
            "from_purchase_order_id" => purchase_order.id,
            "line_count" => receipt.receipt_lines.size
          }
        )
      end

      receipt
    end

    private

    attr_reader :purchase_order, :created_by_user

    def open_lines_for_receiving
      purchase_order.purchase_order_lines
        .where(status: OPEN_FOR_RECEIVE_LINE_STATUSES)
        .includes(:product_variant)
        .order(:line_number)
    end
  end
end
