# frozen_string_literal: true

module Orders
  class PurchaseRequestShowPresenter
    include Rails.application.routes.url_helpers

    def initialize(purchase_request:, document_hub:)
      @purchase_request = purchase_request
      @document_hub = document_hub
    end

    def title
      "Purchase Request ##{purchase_request.id}"
    end

    def status
      purchase_request.status
    end

    def metadata_lines
      lines = []
      lines << purchase_request.notes if purchase_request.notes.present?
      lines
    end

    def metrics
      summary = document_hub.summary
      open_demand = purchase_request.purchase_request_lines
        .select { |line| PurchaseRequest::BUILDABLE_LINE_STATUSES.include?(line.status) }
        .sum(&:requested_quantity)
      [
        { label: "Lines", value: summary.line_count },
        { label: "Buildable", value: summary.buildable_line_count },
        { label: "On PO", value: summary.added_line_count },
        { label: "Open demand", value: open_demand }
      ]
    end

    def attention_items
      Purchasing::DocumentAttention.for_purchase_request(purchase_request:, document_hub:)
    end

    def trail_nodes
      Purchasing::DocumentTrailBuilder.for_purchase_request(purchase_request, document_hub:)
    end

    def sidebar_facts
      [
        { label: "Status", value: purchase_request.status.humanize },
        { label: "Store", value: purchase_request.store.name }
      ]
    end

    def show_related_detail?
      document_hub.purchase_orders.any?
    end

    private

    attr_reader :purchase_request, :document_hub
  end
end
