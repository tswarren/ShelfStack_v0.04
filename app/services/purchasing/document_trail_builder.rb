# frozen_string_literal: true

module Purchasing
  class DocumentTrailBuilder
    include Rails.application.routes.url_helpers

    TrailNode = Data.define(:label, :href, :meta)

    def self.for_purchase_order(purchase_order, document_hub:)
      new(purchase_order:, document_hub:).nodes
    end

    def self.for_receipt(receipt, document_hub:)
      new(receipt:, document_hub:).nodes
    end

    def self.for_purchase_request(purchase_request, document_hub:)
      new(purchase_request:, document_hub:).nodes
    end

    def self.for_return_to_vendor(return_to_vendor, document_hub:)
      new(return_to_vendor:, document_hub:).nodes
    end

    def initialize(purchase_order: nil, receipt: nil, purchase_request: nil, return_to_vendor: nil, document_hub: nil)
      @purchase_order = purchase_order
      @receipt = receipt
      @purchase_request = purchase_request
      @return_to_vendor = return_to_vendor
      @document_hub = document_hub
    end

    def nodes
      return purchase_order_nodes if purchase_order.present?
      return receipt_nodes if receipt.present?
      return purchase_request_nodes if purchase_request.present?
      return return_to_vendor_nodes if return_to_vendor.present?

      []
    end

    private

    attr_reader :purchase_order, :receipt, :purchase_request, :return_to_vendor, :document_hub

    def purchase_order_nodes
      nodes = []

      document_hub.purchase_requests.each do |entry|
        nodes << TrailNode.new(
          label: "TBO ##{entry.purchase_request.id}",
          href: orders_purchase_request_path(entry.purchase_request),
          meta: "#{entry.line_count} #{'line'.pluralize(entry.line_count)} on PO"
        )
      end

      nodes << TrailNode.new(
        label: "PO ##{purchase_order.id}",
        href: orders_purchase_order_path(purchase_order),
        meta: purchase_order.status
      )

      document_hub.receipts.each do |entry|
        nodes << TrailNode.new(
          label: "Receipt ##{entry.receipt.id}",
          href: orders_receipt_path(entry.receipt),
          meta: "#{entry.receipt.status}, #{entry.accepted_quantity} accepted"
        )
      end

      nodes
    end

    def receipt_nodes
      nodes = []
      po = document_hub.purchase_order

      if po.present?
        nodes << TrailNode.new(
          label: "PO ##{po.id}",
          href: orders_purchase_order_path(po),
          meta: po.status
        )
      end

      nodes << TrailNode.new(
        label: "Receipt ##{receipt.id}",
        href: orders_receipt_path(receipt),
        meta: receipt.status
      )

      nodes
    end

    def purchase_request_nodes
      nodes = [
        TrailNode.new(
          label: "TBO ##{purchase_request.id}",
          href: orders_purchase_request_path(purchase_request),
          meta: purchase_request.status
        )
      ]

      document_hub.purchase_orders.each do |entry|
        nodes << TrailNode.new(
          label: "PO ##{entry.purchase_order.id}",
          href: orders_purchase_order_path(entry.purchase_order),
          meta: "#{entry.line_count} #{'line'.pluralize(entry.line_count)}, #{entry.purchase_order.status}"
        )
      end

      nodes
    end

    def return_to_vendor_nodes
      nodes = [
        TrailNode.new(
          label: "Return ##{return_to_vendor.id}",
          href: orders_returns_to_vendor_path(return_to_vendor),
          meta: return_to_vendor.status
        )
      ]

      if document_hub.inventory_posting.present?
        nodes << TrailNode.new(
          label: "Inventory posting ##{document_hub.inventory_posting.id}",
          href: nil,
          meta: "vendor_return"
        )
      end

      nodes
    end
  end
end
