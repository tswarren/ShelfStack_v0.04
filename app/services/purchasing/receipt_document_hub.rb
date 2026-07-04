# frozen_string_literal: true

module Purchasing
  class ReceiptDocumentHub
    Totals = Data.define(:expected, :received, :accepted, :rejected)
    PoLineMatch = Data.define(
      :receipt_line,
      :purchase_order,
      :purchase_order_line,
      :ordered,
      :received_on_po,
      :open_on_po,
      :quantity_matched,
      :match_status,
      :match_source
    )
    DiscrepancyRow = Data.define(:receipt_line, :discrepancy_type, :quantity_delta, :sku)

    Result = Data.define(
      :totals,
      :purchase_order,
      :po_receive_progress,
      :po_line_matches,
      :discrepancies,
      :inventory_posting
    )

    def self.call(receipt)
      new(receipt).call
    end

    def initialize(receipt)
      @receipt = receipt
    end

    def call
      po = receipt.purchase_order
      po_progress = po.present? ? PurchaseOrderDocumentHub.call(po).receive_progress : nil

      Result.new(
        totals: totals,
        purchase_order: po,
        po_receive_progress: po_progress,
        po_line_matches: po_line_matches,
        discrepancies: discrepancies,
        inventory_posting: receipt.inventory_posting
      )
    end

    private

    attr_reader :receipt

    def totals
      lines = receipt.receipt_lines.to_a
      Totals.new(
        expected: lines.sum(&:quantity_expected),
        received: lines.sum(&:quantity_received),
        accepted: lines.sum(&:quantity_accepted),
        rejected: lines.sum(&:quantity_rejected)
      )
    end

    def po_line_matches
      receipt.receipt_lines.flat_map { |receipt_line| rows_for(receipt_line) }
    end

    def rows_for(receipt_line)
      confirmed = ReceiptLineMatch.confirmed_matches
                                  .where(receipt_line: receipt_line)
                                  .includes(purchase_order_line: :purchase_order, purchase_order: [])

      if confirmed.any?
        confirmed.map { |match| po_line_match_row(receipt_line, match.purchase_order_line, match) }
      elsif receipt_line.purchase_order_line.present?
        [ po_line_match_row(receipt_line, receipt_line.purchase_order_line, nil) ]
      else
        [ po_line_match_row(receipt_line, nil, nil) ]
      end
    end

    def po_line_match_row(receipt_line, po_line, match)
      po = po_line&.purchase_order || match&.purchase_order
      open_on_po = if po_line.present? && po.present?
        po.open_quantity_for_line(po_line)
      end

      PoLineMatch.new(
        receipt_line: receipt_line,
        purchase_order: po,
        purchase_order_line: po_line,
        ordered: po_line&.quantity_ordered,
        received_on_po: po_line&.quantity_received,
        open_on_po: open_on_po,
        quantity_matched: match&.quantity_matched,
        match_status: match&.match_status,
        match_source: match&.match_source
      )
    end

    def discrepancies
      receipt.receipt_lines.flat_map do |receipt_line|
        receipt_line.receiving_discrepancies.map do |discrepancy|
          DiscrepancyRow.new(
            receipt_line: receipt_line,
            discrepancy_type: discrepancy.discrepancy_type,
            quantity_delta: discrepancy.quantity_delta,
            sku: receipt_line.product_variant.sku
          )
        end
      end
    end
  end
end
