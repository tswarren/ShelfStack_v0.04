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

    def show_customer_allocations?
      receipt.draft? ? projected_allocation_rows.any? : receipt.receipt_lines.any? { |line| line.receipt_line_allocations.any? }
    end

    def stock_quantity_label
      receipt.draft? ? "Projected stock quantity" : "Actual stock quantity"
    end

    def pre_post_allocation_message
      return nil unless receipt.draft?

      count = projected_special_order_count
      return nil if count.zero?

      "Will auto-allocate to #{count} special #{'order'.pluralize(count)} on post"
    end

    def customer_allocation_rows
      return posted_customer_allocation_rows unless receipt.draft?

      projected_allocation_rows
    end

    def allocation_summary_rows
      receipt.receipt_lines.map do |line|
        po_line = line.purchase_order_line
        customer_qty = if receipt.draft?
          projected_customer_qty_for(line)
        else
          line.receipt_line_allocations.sum(:quantity_allocated)
        end
        stock_qty = [ line.quantity_accepted.to_i - customer_qty, 0 ].max

        {
          receipt_line_number: line.line_number,
          variant: line.product_variant,
          quantity_accepted: line.quantity_accepted,
          customer_quantity: customer_qty,
          stock_quantity: stock_qty,
          stock_label: stock_quantity_label,
          po_allocations: po_allocation_details(po_line)
        }
      end
    end

    def show_po_allocations?
      po_allocation_rows.any?
    end

    def po_allocation_rows
      receipt.receipt_lines.flat_map do |line|
        next [] if line.purchase_order_line.blank?

        po_allocation_details(line.purchase_order_line).map do |detail|
          detail.merge(
            receipt_line_number: line.line_number,
            po_line_number: line.purchase_order_line.line_number,
            variant: line.product_variant
          )
        end
      end
    end

    def show_allocation_summary?
      allocation_summary_rows.any? { |row| row[:customer_quantity].positive? || row[:po_allocations].any? }
    end

    private

    attr_reader :receipt, :document_hub

    def posted_customer_allocation_rows
      @posted_customer_allocation_rows ||= compute_posted_customer_allocation_rows
    end

    def compute_posted_customer_allocation_rows
      receipt.receipt_lines.flat_map do |line|
        line.receipt_line_allocations.map do |allocation|
          request = allocation.customer_request_line&.customer_request
          {
            receipt_line_number: line.line_number,
            variant: line.product_variant,
            customer_name: allocation.special_order&.customer&.display_name || request&.customer&.display_name,
            request_number: request&.request_number,
            request_id: request&.id,
            quantity: allocation.quantity_allocated,
            special_order_id: allocation.special_order_id,
            state: "actual"
          }
        end
      end
    end

    def projected_allocation_rows
      @projected_allocation_rows ||= compute_projected_allocation_rows
    end

    def compute_projected_allocation_rows
      receipt.receipt_lines.flat_map do |line|
        po_line = line.purchase_order_line
        next [] if po_line.blank?

        remaining_accept = line.quantity_accepted.to_i
        rows = []
        po_line.purchase_order_line_allocations.open_allocations.order(:created_at).each do |allocation|
          break if remaining_accept.zero?

          qty = [ allocation.quantity_allocated - allocation.quantity_received, remaining_accept ].min
          next if qty.zero?

          remaining_accept -= qty
          request = allocation.customer_request_line&.customer_request
          rows << {
            receipt_line_number: line.line_number,
            variant: line.product_variant,
            customer_name: allocation.special_order&.customer&.display_name || request&.customer&.display_name,
            request_number: request&.request_number,
            request_id: request&.id,
            quantity: qty,
            special_order_id: allocation.special_order_id,
            state: "projected"
          }
        end
        rows
      end
    end

    def projected_special_order_count
      projected_allocation_rows.map { |row| row[:special_order_id] }.compact.uniq.size
    end

    def projected_customer_qty_for(line)
      projected_allocation_rows
        .select { |row| row[:receipt_line_number] == line.line_number }
        .sum { |row| row[:quantity] }
    end

    def po_allocation_details(po_line)
      return [] if po_line.blank?

      po_line.purchase_order_line_allocations.open_allocations.map do |allocation|
        {
          special_order_id: allocation.special_order_id,
          customer_name: allocation.special_order&.customer&.display_name,
          quantity_allocated: allocation.quantity_allocated,
          quantity_received: allocation.quantity_received,
          quantity_remaining: allocation.quantity_allocated - allocation.quantity_received
        }
      end
    end

    def helpers
      ApplicationController.helpers
    end
  end
end
