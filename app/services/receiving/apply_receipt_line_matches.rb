# frozen_string_literal: true

module Receiving
  class ApplyReceiptLineMatches
    class ApplyError < StandardError; end

    def self.call!(receipt:, actor:, matches:)
      new(receipt:, actor:, matches:).call!
    end

    def initialize(receipt:, actor:, matches:)
      @receipt = receipt
      @actor = actor
      @matches = Array(matches)
    end

    def call!
      raise ApplyError, "Receipt must be draft" unless receipt.draft?

      applied = []
      Receipt.transaction do
        matches.each do |match_attrs|
          idempotency_key = match_attrs[:idempotency_key] ||
            "receipt:#{receipt.id}:line:#{match_attrs[:receipt_line_id]}:po_line:#{match_attrs[:purchase_order_line_id]}"
          existing = ReceiptLineMatch.find_by(store: receipt.store, idempotency_key: idempotency_key)
          if existing&.confirmed?
            applied << existing
            next
          end

          receipt_line = receipt.receipt_lines.find(match_attrs[:receipt_line_id])
          po_line = PurchaseOrderLine.find(match_attrs[:purchase_order_line_id])
          qty = match_attrs[:quantity_matched].to_i
          validate_match!(receipt_line, po_line, qty)

          record = ReceiptLineMatch.create!(
            store: receipt.store,
            receipt: receipt,
            receipt_line: receipt_line,
            purchase_order: po_line.purchase_order,
            purchase_order_line: po_line,
            product: receipt_line.product_variant.product,
            product_variant: receipt_line.product_variant,
            quantity_matched: qty,
            match_status: "confirmed",
            match_source: match_attrs[:match_source] || "manual",
            matched_by_user: actor,
            matched_at: Time.current,
            idempotency_key: idempotency_key
          )

          AuditEvents.record!(
            actor: actor,
            event_name: "receipt_line_match.confirmed",
            auditable: record,
            details: {
              "receipt_line_id" => receipt_line.id,
              "purchase_order_line_id" => po_line.id,
              "quantity_matched" => qty
            }
          )
          applied << record
        end
      end

      applied
    end

    private

    attr_reader :receipt, :actor, :matches

    def validate_match!(receipt_line, po_line, qty)
      raise ApplyError, "Quantity must be positive" if qty <= 0

      if receipt_line.product_variant_id != po_line.product_variant_id
        raise ApplyError, "Variant mismatch between receipt line and PO line"
      end

      confirmed_total = ReceiptLineMatch.confirmed_matches.where(receipt_line: receipt_line).sum(:quantity_matched)
      if confirmed_total + qty > receipt_line.quantity_accepted
        raise ApplyError, "Matched quantity exceeds accepted quantity on receipt line"
      end

      Purchasing::CustomerDirectPurchaseOrderGate.assert_receivable!(po_line.purchase_order)
    end
  end
end
