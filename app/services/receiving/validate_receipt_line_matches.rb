# frozen_string_literal: true

module Receiving
  class ValidateReceiptLineMatches
    class ValidationError < StandardError; end

    def self.call!(receipt:)
      new(receipt:).call!
    end

    def initialize(receipt:)
      @receipt = receipt
    end

    def call!
      receipt.receipt_lines.reload.each { |line| validate_line!(line) }
      validate_adapter_views!
    end

    private

    attr_reader :receipt

    def validate_line!(line)
      matches = ReceiptLineMatch.confirmed_matches.where(receipt_line: line)
      return if matches.empty?

      total_matched = matches.sum(:quantity_matched)
      if total_matched > line.quantity_accepted
        raise ValidationError,
              "Line #{line.line_number}: matched quantity (#{total_matched}) exceeds accepted quantity (#{line.quantity_accepted})"
      end

      matches.each do |match|
        validate_match!(line, match)
      end
    end

    def validate_match!(line, match)
      if match.product_variant_id != line.product_variant_id
        raise ValidationError,
              "Line #{line.line_number}: match variant does not match receipt line variant"
      end

      Purchasing::CustomerDirectPurchaseOrderGate.assert_receivable!(match.purchase_order)

      po_line = match.purchase_order_line
      open_qty = Purchasing::PoLineQuantitySummary.for(po_line).open_to_receive_quantity
      matched_on_receipt = ReceiptLineMatch.confirmed_matches
                                            .where(receipt: receipt, purchase_order_line: po_line)
                                            .sum(:quantity_matched)
      if matched_on_receipt > open_qty
        raise ValidationError,
              "PO line #{po_line.line_number}: matched quantity (#{matched_on_receipt}) exceeds open to receive (#{open_qty})"
      end
    end

    def validate_adapter_views!
      Receiving::ReceiptPostingMatchAdapter.call(receipt: receipt).each do |view|
        next if view.purchase_order_line.blank?

        if view.quantity_accepted > view.receipt_line.quantity_accepted
          raise ValidationError,
                "Line #{view.receipt_line.line_number}: adapter matched quantity exceeds accepted quantity"
        end
      end
    end
  end
end
