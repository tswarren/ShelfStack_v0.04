# frozen_string_literal: true

module Orders
  class PurchaseOrderShowPresenter
    include Rails.application.routes.url_helpers

    def initialize(purchase_order:, document_hub:, order_summary:, sourcing_warnings:, line_demand_breakdowns: [])
      @purchase_order = purchase_order
      @document_hub = document_hub
      @order_summary = order_summary
      @sourcing_warnings = sourcing_warnings
      @line_demand_breakdowns = line_demand_breakdowns.index_by { |entry| entry.line.id }
    end

    def title
      "Purchase Order ##{purchase_order.id}"
    end

    def status
      purchase_order.status
    end

    def metadata_lines
      lines = [ "Vendor: #{purchase_order.vendor.name}" ]
      lines << purchase_order.notes if purchase_order.notes.present?
      lines
    end

    def metrics
      progress = document_hub.receive_progress
      [
        { label: "Ordered", value: progress.ordered },
        { label: "Received", value: progress.received },
        { label: "Open", value: progress.open },
        { label: "Total cost", value: helpers.format_cents(order_summary.total_cost_cents) },
        {
          label: "Net discount",
          value: order_summary.net_discount_bps ? helpers.format_basis_points(order_summary.net_discount_bps) : "—"
        }
      ]
    end

    def attention_items
      Purchasing::DocumentAttention.for_purchase_order(
        purchase_order:,
        document_hub:,
        sourcing_warnings:
      )
    end

    def trail_nodes
      Purchasing::DocumentTrailBuilder.for_purchase_order(purchase_order, document_hub:)
    end

    def sidebar_facts
      [
        { label: "Vendor", value: purchase_order.vendor.name },
        { label: "Status", value: purchase_order.status.humanize }
      ]
    end

    def line_flags(line)
      flags = []
      if purchase_order.vendor.present?
        sourcing = Purchasing::SourcingLookup.for(variant: line.product_variant, vendor: purchase_order.vendor)
        flags << "No source" unless sourcing.sourcing_record_present
      end
      flags << "Discrepancy" if discrepancy_line_ids.include?(line.id)
      breakdown = line_demand_breakdown(line)
      if breakdown&.coverage_mode == :planned && breakdown.plan_rows.any?
        qty = breakdown.demand_allocated_quantity
        flags << "#{qty} planned for #{'customer'.pluralize(qty)}" if qty.positive?
      elsif breakdown&.demand_allocated_quantity.to_i.positive?
        qty = breakdown.demand_allocated_quantity
        flags << "#{qty} for #{'customer'.pluralize(qty)}"
      end
      flags
    end

    def line_demand_breakdown(line)
      line_demand_breakdowns[line.id]
    end

    def customer_allocations_present?
      line_demand_breakdowns.values.any? do |entry|
        entry.demand_allocated_quantity.positive? || entry.allocation_rows.any? || entry.plan_rows.any?
      end
    end

    def show_line_activity?
      document_hub.line_activity.any? { |entry| entry.receipt_lines.any? }
    end

    def show_discrepancies?
      document_hub.discrepancies.any?
    end

    def show_related_detail?
      document_hub.purchase_requests.any? || document_hub.receipts.any?
    end

    private

    attr_reader :purchase_order, :document_hub, :order_summary, :sourcing_warnings, :line_demand_breakdowns

    def discrepancy_line_ids
      @discrepancy_line_ids ||= document_hub.discrepancies.filter_map(&:purchase_order_line).map(&:id).uniq
    end

    def helpers
      ApplicationController.helpers
    end
  end
end
