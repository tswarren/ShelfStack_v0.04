# frozen_string_literal: true

module Purchasing
  class PostReceipt
    class PostingError < StandardError; end

    def self.call(receipt:, posted_by_user:)
      new(receipt:, posted_by_user:).call
    end

    def initialize(receipt:, posted_by_user:)
      @receipt = receipt
      @posted_by_user = posted_by_user
    end

    def call
      return receipt.inventory_posting if receipt.posted?

      raise PostingError, "Receipt is not a draft" unless receipt.draft?
      raise PostingError, "Receipt has no lines" if receipt.receipt_lines.empty?

      receipt.receipt_lines.each do |line|
        next if line.quantity_accepted.zero?

        Inventory::Eligibility.ensure_eligible!(line.product_variant)
      end

      posting = nil
      Receipt.transaction do
        normalize_accepted_quantities!
        record_discrepancies!

        postable_lines = receipt.receipt_lines.select { |line| line.quantity_accepted.positive? }
        if postable_lines.empty?
          raise PostingError, "At least one line must have accepted quantity greater than zero."
        end

        lines = postable_lines.map do |line|
          Inventory::Post::LinePayload.new(
            product_variant: line.product_variant,
            quantity_delta: line.quantity_accepted,
            movement_type: "received",
            manual_unit_cost_cents: line.unit_cost_cents,
            cost_source: line.unit_cost_cents.present? ? "receipt_cost" : nil,
            inventory_location: nil,
            inventory_reason_code: nil
          )
        end

        posting = Inventory::Post.call(
          store: receipt.store,
          posted_by_user: posted_by_user,
          posting_type: "receiving",
          source: receipt,
          lines: lines,
          idempotency_key: "receipt:#{receipt.id}",
          notes: nil
        )

        UpdatePoLineQuantities.call(receipt: receipt)
        ReceiptPostingGuards.assert_no_mixed_claims!(receipt)
        Receiving::AllocateCustomerDemandFromReceipt.call!(receipt: receipt, posted_by_user: posted_by_user)
        DemandAllocations::ConvertInboundFromReceipt.call!(receipt: receipt, actor: posted_by_user)

        receipt.update!(
          status: "posted",
          posted_at: posting&.posted_at || Time.current,
          posted_by_user: posted_by_user,
          inventory_posting: posting
        )

        AuditEvents.record!(
          actor: posted_by_user,
          event_name: "receipt.posted",
          auditable: receipt,
          details: {
            "inventory_posting_id" => posting&.id,
            "line_count" => receipt.receipt_lines.size
          }
        )
      end

      posting
    end

    private

    attr_reader :receipt, :posted_by_user

    def normalize_accepted_quantities!
      receipt.receipt_lines.each(&:valid?)
    end

    def record_discrepancies!
      receipt.receipt_lines.each do |line|
        next if line.quantity_received == line.quantity_expected

        delta = line.quantity_received - line.quantity_expected
        discrepancy_type = delta.negative? ? "short" : "over"

        ReceivingDiscrepancy.create!(
          receipt_line: line,
          discrepancy_type: discrepancy_type,
          quantity_delta: delta
        )
      end
    end
  end
end
