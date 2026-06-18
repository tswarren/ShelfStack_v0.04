# frozen_string_literal: true

module Orders
  class ReturnToVendorShowPresenter
    include Rails.application.routes.url_helpers

    def initialize(return_to_vendor:, document_hub:)
      @return_to_vendor = return_to_vendor
      @document_hub = document_hub
    end

    def title
      "Return to Vendor ##{return_to_vendor.id}"
    end

    def status
      return_to_vendor.status
    end

    def metadata_lines
      lines = [ "Vendor: #{return_to_vendor.vendor.name}" ]
      lines << return_to_vendor.notes if return_to_vendor.notes.present?
      lines
    end

    def metrics
      totals = document_hub.totals
      metrics = [
        { label: "Units", value: totals.units },
        { label: "Est. credit", value: helpers.format_cents(totals.total_credit_cents) },
        { label: "Est. cost", value: helpers.format_cents(totals.total_cost_cents) }
      ]
      if document_hub.inventory_posting.present?
        metrics << { label: "Posting", value: "##{document_hub.inventory_posting.id}" }
      end
      metrics
    end

    def attention_items
      Purchasing::DocumentAttention.for_return_to_vendor(return_to_vendor:, document_hub:)
    end

    def trail_nodes
      Purchasing::DocumentTrailBuilder.for_return_to_vendor(return_to_vendor, document_hub:)
    end

    def sidebar_facts
      facts = [
        { label: "Vendor", value: return_to_vendor.vendor.name },
        { label: "Status", value: return_to_vendor.status.humanize }
      ]
      if document_hub.inventory_posting.present?
        facts << { label: "Inventory posting", value: "##{document_hub.inventory_posting.id}" }
      end
      facts
    end

    private

    attr_reader :return_to_vendor, :document_hub

    def helpers
      ApplicationController.helpers
    end
  end
end
