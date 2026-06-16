# frozen_string_literal: true

module Inventory
  class PostAdjustment
    class PostingError < StandardError; end

    def self.call(adjustment:, posted_by_user:)
      new(adjustment:, posted_by_user:).call
    end

    def initialize(adjustment:, posted_by_user:)
      @adjustment = adjustment
      @posted_by_user = posted_by_user
    end

    def call
      return adjustment.inventory_posting if adjustment.posted?

      raise PostingError, "Adjustment is not a draft" unless adjustment.draft?
      raise PostingError, "Adjustment has no lines" if adjustment.inventory_adjustment_lines.empty?

      adjustment.inventory_adjustment_lines.each do |line|
        raise PostingError, "Line #{line.line_number} has zero quantity" if line.quantity_delta.zero?

        Eligibility.ensure_eligible!(line.product_variant)
      end

      posting_type = adjustment.adjustment_type
      movement_type = case adjustment.adjustment_type
      when "opening_inventory" then "opening_balance"
      when "balance_correction" then "correction"
      else "manual_adjustment"
      end

      lines = adjustment.inventory_adjustment_lines.map do |line|
        Post::LinePayload.new(
          product_variant: line.product_variant,
          quantity_delta: line.quantity_delta,
          movement_type: movement_type,
          manual_unit_cost_cents: line.unit_cost_cents,
          inventory_location: line.inventory_location,
          inventory_reason_code: line.inventory_reason_code
        )
      end

      posting = nil
      InventoryAdjustment.transaction do
        posting = Post.call(
          store: adjustment.store,
          posted_by_user: posted_by_user,
          posting_type: posting_type,
          source: adjustment,
          lines: lines,
          idempotency_key: "inventory_adjustment:#{adjustment.id}",
          notes: adjustment.notes
        )

        adjustment.update!(
          status: "posted",
          posted_at: posting.posted_at,
          posted_by_user: posted_by_user,
          inventory_posting: posting
        )

        AuditEvents.record!(
          actor: posted_by_user,
          event_name: "inventory_adjustment.posted",
          auditable: adjustment,
          details: { "inventory_posting_id" => posting.id }
        )
      end

      posting
    end

    private

    attr_reader :adjustment, :posted_by_user
  end
end
