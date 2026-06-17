# frozen_string_literal: true

module Purchasing
  class ClosePurchaseOrder
    class CloseError < StandardError; end

    CLOSABLE_PO_STATUSES = %w[submitted partially_received received].freeze
    OPEN_LINE_STATUSES = %w[open partially_received backordered].freeze

    def self.call(purchase_order:, closed_by_user:)
      new(purchase_order:, closed_by_user:).call
    end

    def initialize(purchase_order:, closed_by_user:)
      @purchase_order = purchase_order
      @closed_by_user = closed_by_user
    end

    def call
      raise CloseError, "Purchase order cannot be closed" unless closable?

      PurchaseOrder.transaction do
        purchase_order.purchase_order_lines.each do |line|
          close_line!(line)
        end

        purchase_order.update!(status: "closed")

        AuditEvents.record!(
          actor: closed_by_user,
          event_name: "purchase_order.closed",
          auditable: purchase_order,
          details: { "line_count" => purchase_order.purchase_order_lines.size }
        )
      end

      purchase_order
    end

    def closable?
      return false unless CLOSABLE_PO_STATUSES.include?(purchase_order.status)

      return true if purchase_order.status == "received"

      purchase_order.purchase_order_lines.any? { |line| line_closable?(line) }
    end

    private

    attr_reader :purchase_order, :closed_by_user

    def close_line!(line)
      return unless line_closable?(line)

      line.closure_update = true
      line.status = resolved_closed_status(line)
      line.save!
    end

    def line_closable?(line)
      OPEN_LINE_STATUSES.include?(line.status)
    end

    def resolved_closed_status(line)
      if line.quantity_received.positive? && line.quantity_received < line.quantity_ordered
        "closed_short"
      else
        "closed"
      end
    end
  end
end
