# frozen_string_literal: true

module Orders
  class ReceiptShowPresenter
    include Rails.application.routes.url_helpers

    def initialize(receipt:, document_hub:)
      @receipt = receipt
      @document_hub = document_hub
    end

    def title
      "Receipt ##{receipt.id}"
    end

    def status
      receipt.status
    end

    def metadata_lines
      lines = [
        "Vendor: #{receipt.vendor.name}",
        "Type: #{receipt.receipt_type.humanize}"
      ]
      lines
    end

    def metrics
      totals = document_hub.totals
      metrics = [
        { label: "Expected", value: totals.expected },
        { label: "Received", value: totals.received },
        { label: "Accepting", value: totals.accepted },
        { label: "Rejected", value: totals.rejected }
      ]
      if document_hub.inventory_posting.present?
        metrics << { label: "Posting", value: "##{document_hub.inventory_posting.id}" }
      end
      metrics
    end

    def attention_items
      Purchasing::DocumentAttention.for_receipt(receipt:, document_hub:)
    end

    def trail_nodes
      Purchasing::DocumentTrailBuilder.for_receipt(receipt, document_hub:)
    end

    def sidebar_facts
      facts = [
        { label: "Vendor", value: receipt.vendor.name },
        { label: "Status", value: receipt.status.humanize }
      ]
      if document_hub.purchase_order.present?
        facts << {
          label: "Purchase order",
          value: "##{document_hub.purchase_order.id}",
          href: orders_purchase_order_path(document_hub.purchase_order)
        }
      end
      if document_hub.inventory_posting.present?
        facts << { label: "Inventory posting", value: "##{document_hub.inventory_posting.id}" }
      end
      facts
    end

    def show_po_alignment?
      document_hub.purchase_order.present? && document_hub.po_line_matches.any?
    end

    def show_discrepancies?
      document_hub.discrepancies.any?
    end

    private

    attr_reader :receipt, :document_hub

    def helpers
      ApplicationController.helpers
    end
  end
end
