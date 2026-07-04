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
      [
        "Vendor: #{receipt.vendor.name}",
        "Type: #{receipt.receipt_type.humanize}"
      ]
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
      document_hub.po_line_matches.any? { |match| match.purchase_order_line.present? }
    end

    def show_discrepancies?
      document_hub.discrepancies.any?
    end

    def show_customer_allocations?
      customer_allocation_rows.any?
    end

    def stock_quantity_label
      receipt.draft? ? "Projected stock quantity" : "Actual stock quantity"
    end

    def pre_post_allocation_message
      return nil unless receipt.draft?

      preview = demand_impact_preview
      return preview.message if preview&.message.present?

      count = projected_demand_line_count
      return nil if count.zero?

      "Will convert inbound demand for #{count} #{'line'.pluralize(count)} on post"
    end

    def demand_impact_preview
      return nil unless receipt.draft?

      @demand_impact_preview ||= begin
        impact = Receiving::ReceiptDemandImpactPreview.call(receipt: receipt)
        OpenStruct.new(
          customer_ready: impact.total_customer_ready,
          shelf: impact.total_shelf,
          message: if impact.total_customer_ready.positive?
                     "#{impact.total_customer_ready} #{'copy'.pluralize(impact.total_customer_ready)} customer-ready; #{impact.total_shelf} to shelf stock"
                   end
        )
      end
    end

    def customer_allocation_rows
      receipt.draft? ? projected_allocation_rows : posted_customer_allocation_rows
    end

    def allocation_summary_rows
      receipt.receipt_lines.map do |line|
        customer_qty = customer_quantity_for(line)
        stock_qty = [ line.quantity_accepted.to_i - customer_qty, 0 ].max
        po_details = adapter_views_for_line(line).flat_map do |view|
          po_allocation_details(view.purchase_order_line)
        end

        {
          receipt_line_number: line.line_number,
          variant: line.product_variant,
          quantity_accepted: line.quantity_accepted,
          customer_quantity: customer_qty,
          stock_quantity: stock_qty,
          stock_label: stock_quantity_label,
          po_allocations: po_details
        }
      end
    end

    def show_po_allocations?
      po_allocation_rows.any?
    end

    def po_allocation_rows
      adapter_views.flat_map do |view|
        next [] if view.purchase_order_line.blank?

        po_allocation_details(view.purchase_order_line).map do |detail|
          detail.merge(
            receipt_line_number: view.receipt_line.line_number,
            po_line_number: view.purchase_order_line.line_number,
            purchase_order_id: view.purchase_order_line.purchase_order_id,
            variant: view.receipt_line.product_variant
          )
        end
      end
    end

    def show_allocation_summary?
      allocation_summary_rows.any? { |row| row[:customer_quantity].positive? || row[:po_allocations].any? }
    end

    def post_confirmation_message
      rows = allocation_summary_rows
      customer_qty = rows.sum { |row| row[:customer_quantity] }
      stock_qty = rows.sum { |row| row[:stock_quantity] }
      accepted_qty = rows.sum { |row| row[:quantity_accepted] }
      ready_count = customer_allocation_rows.map { |row| row[:demand_line_id] }.uniq.size

      parts = [ "Receipt posted. Inventory increased by #{accepted_qty}." ]
      parts << "#{ready_count} customer #{'demand'.pluralize(ready_count)} #{'is'.pluralize(ready_count)} now ready for pickup (#{customer_qty} #{'copy'.pluralize(customer_qty)})." if customer_qty.positive?
      parts << "#{stock_qty} #{'copy'.pluralize(stock_qty)} added to available stock." if stock_qty.positive?
      parts.join(" ")
    end

    private

    attr_reader :receipt, :document_hub

    def adapter_views
      @adapter_views ||= Receiving::ReceiptPostingMatchAdapter.call(receipt: receipt)
    end

    def adapter_views_for_line(line)
      adapter_views.select { |view| view.receipt_line.id == line.id }
    end

    def posted_customer_allocation_rows
      @posted_customer_allocation_rows ||= receipt.receipt_lines.flat_map do |line|
        demand_allocations_for_receipt_line(line).map do |allocation|
          demand_line = allocation.demand_line
          {
            receipt_line_number: line.line_number,
            variant: line.product_variant,
            customer_name: demand_line.display_customer_name,
            demand_number: demand_line.demand_number,
            demand_line_id: demand_line.id,
            quantity: allocation.quantity_allocated,
            state: "actual"
          }
        end
      end
    end

    def projected_allocation_rows
      @projected_allocation_rows ||= adapter_views.flat_map do |view|
        remaining_accept = view.quantity_accepted
        rows = []
        inbound_allocations_for(view.purchase_order_line).each do |allocation|
          break if remaining_accept.zero?

          qty = [ allocation.quantity_allocated, remaining_accept ].min
          next if qty.zero?

          remaining_accept -= qty
          demand_line = allocation.demand_line
          rows << {
            receipt_line_number: view.receipt_line.line_number,
            variant: view.receipt_line.product_variant,
            customer_name: demand_line.display_customer_name,
            demand_number: demand_line.demand_number,
            demand_line_id: demand_line.id,
            quantity: qty,
            state: "projected"
          }
        end
        rows
      end
    end

    def projected_demand_line_count
      projected_allocation_rows.map { |row| row[:demand_line_id] }.uniq.size
    end

    def customer_quantity_for(line)
      if receipt.draft?
        projected_allocation_rows
          .select { |row| row[:receipt_line_number] == line.line_number }
          .sum { |row| row[:quantity] }
      else
        demand_allocations_for_receipt_line(line).sum(:quantity_allocated)
      end
    end

    def demand_allocations_for_receipt_line(line)
      DemandAllocation.where(conversion_receipt_line_id: line.id)
                      .where(allocation_kind: "on_hand")
    end

    def inbound_allocations_for(po_line)
      DemandAllocation.active_allocations
                      .inbound_kind
                      .where(purchase_order_line_id: po_line.id)
                      .includes(:demand_line)
                      .order(:allocated_at, :id)
    end

    def po_allocation_details(po_line)
      return [] if po_line.blank?

      inbound_allocations_for(po_line).map do |allocation|
        demand_line = allocation.demand_line
        {
          demand_line_id: demand_line.id,
          demand_number: demand_line.demand_number,
          customer_name: demand_line.display_customer_name,
          quantity_allocated: allocation.quantity_allocated,
          quantity_received: 0,
          quantity_remaining: allocation.quantity_allocated
        }
      end
    end

    def helpers
      ApplicationController.helpers
    end
  end
end
