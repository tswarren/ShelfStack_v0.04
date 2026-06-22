# frozen_string_literal: true

module Purchasing
  class DocumentAttention
    AttentionItem = Data.define(:message, :link_path, :link_label)

    def self.for_purchase_order(purchase_order:, document_hub:, sourcing_warnings:)
      new(purchase_order:, document_hub:, sourcing_warnings:).items
    end

    def self.for_receipt(receipt:, document_hub:)
      new(receipt:, document_hub:).items
    end

    def self.for_purchase_request(purchase_request:, document_hub:)
      new(purchase_request:, document_hub:).items
    end

    def self.for_return_to_vendor(return_to_vendor:, document_hub:)
      new(return_to_vendor:, document_hub:).items
    end

    def initialize(purchase_order: nil, receipt: nil, purchase_request: nil, return_to_vendor: nil,
                   document_hub: nil, sourcing_warnings: [])
      @purchase_order = purchase_order
      @receipt = receipt
      @purchase_request = purchase_request
      @return_to_vendor = return_to_vendor
      @document_hub = document_hub
      @sourcing_warnings = Array(sourcing_warnings)
    end

    def items
      return purchase_order_items if purchase_order.present?
      return receipt_items if receipt.present?
      return purchase_request_items if purchase_request.present?
      return return_to_vendor_items if return_to_vendor.present?

      []
    end

    private

    attr_reader :purchase_order, :receipt, :purchase_request, :return_to_vendor, :document_hub, :sourcing_warnings

    def purchase_order_items
      items = sourcing_warnings.map { |message| AttentionItem.new(message:, link_path: nil, link_label: nil) }

      open_lines = purchase_order.purchase_order_lines.count do |line|
        purchase_order.open_quantity_for_line(line).positive?
      end
      if open_lines.positive? && %w[submitted partially_received].include?(purchase_order.status)
        items << AttentionItem.new(
          message: "#{open_lines} #{'line'.pluralize(open_lines)} still open to receive.",
          link_path: nil,
          link_label: nil
        )
      end

      discrepancy_count = document_hub.discrepancies.size
      if discrepancy_count.positive?
        items << AttentionItem.new(
          message: "#{discrepancy_count} receiving #{'discrepancy'.pluralize(discrepancy_count)} recorded on related receipts.",
          link_path: nil,
          link_label: nil
        )
      end

      customer_alloc_qty = purchase_order.purchase_order_lines.sum do |line|
        Purchasing::PurchaseOrderLineDemandBreakdown.new(purchase_order).for_line(line).customer_allocated_quantity
      end
      if customer_alloc_qty.positive? && %w[submitted partially_received].include?(purchase_order.status)
        items << AttentionItem.new(
          message: "#{customer_alloc_qty} #{'unit'.pluralize(customer_alloc_qty)} on open lines reserved for customers.",
          link_path: nil,
          link_label: nil
        )
      end

      items
    end

    def receipt_items
      items = []

      receipt.receipt_lines.each do |line|
        next unless line.quantity_rejected.positive?

        reason = line.exception_reason.present? ? " (#{line.exception_reason.humanize})" : ""
        items << AttentionItem.new(
          message: "Line #{line.line_number} has #{line.quantity_rejected} rejected units#{reason}.",
          link_path: nil,
          link_label: nil
        )
      end

      document_hub.discrepancies.each do |row|
        items << AttentionItem.new(
          message: "Line #{row.receipt_line.line_number} #{row.discrepancy_type} by #{row.quantity_delta}.",
          link_path: nil,
          link_label: nil
        )
      end

      if receipt.draft?
        reserved_lines = receipt.receipt_lines.count do |line|
          Purchasing::ReceiptLineDemand.customer_reserved_open(line.purchase_order_line).positive?
        end
        if reserved_lines.positive?
          items << AttentionItem.new(
            message: "#{reserved_lines} #{'line'.pluralize(reserved_lines)} include units reserved for customers.",
            link_path: nil,
            link_label: nil
          )
        end
      end

      items
    end

    def purchase_request_items
      items = []
      pending_lines = purchase_request.purchase_request_lines.select do |line|
        %w[open sourcing_needed ready_to_order partially_ordered].include?(line.status)
      end

      if pending_lines.any?
        items << AttentionItem.new(
          message: "#{pending_lines.size} #{'line'.pluralize(pending_lines.size)} still buildable for purchase orders.",
          link_path: nil,
          link_label: nil
        )
      end

      sourcing_lines = pending_lines.select { |line| line.status == "sourcing_needed" }
      if sourcing_lines.any?
        items << AttentionItem.new(
          message: "#{sourcing_lines.size} #{'line'.pluralize(sourcing_lines.size)} marked sourcing needed.",
          link_path: nil,
          link_label: nil
        )
      end

      items
    end

    def return_to_vendor_items
      items = []
      balances = InventoryBalance
        .where(store: return_to_vendor.store, product_variant_id: return_to_vendor.return_to_vendor_lines.map(&:product_variant_id))
        .index_by(&:product_variant_id)

      return_to_vendor.return_to_vendor_lines.each do |line|
        returnability = ReturnabilityResolver.resolve(variant: line.product_variant, vendor: return_to_vendor.vendor)
        if returnability == "non_returnable"
          items << AttentionItem.new(
            message: "Line #{line.line_number} (#{line.product_variant.sku}) is non-returnable for this vendor.",
            link_path: nil,
            link_label: nil
          )
        end

        on_hand = balances[line.product_variant_id]&.quantity_on_hand || 0
        if line.quantity > on_hand
          items << AttentionItem.new(
            message: "Line #{line.line_number} return qty #{line.quantity} exceeds on hand (#{on_hand}).",
            link_path: nil,
            link_label: nil
          )
        end
      end

      items
    end
  end
end
