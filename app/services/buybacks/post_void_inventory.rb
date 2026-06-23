# frozen_string_literal: true

module Buybacks
  class PostVoidInventory
    def self.call(buyback_void:, posted_by_user:)
      new(buyback_void:, posted_by_user:).call
    end

    def initialize(buyback_void:, posted_by_user:)
      @buyback_void = buyback_void
      @posted_by_user = posted_by_user
      @session = buyback_void.buyback_session
    end

    def call
      original_posting = session.inventory_posting
      return nil if original_posting.blank?

      payloads = original_posting.inventory_ledger_entries.map do |entry|
        Inventory::Post::LinePayload.new(
          product_variant: entry.product_variant,
          quantity_delta: -entry.quantity_delta,
          movement_type: entry.movement_type,
          manual_unit_cost_cents: entry.unit_cost_cents,
          cost_source: entry.cost_source,
          inventory_location: entry.inventory_location,
          inventory_reason_code: entry.inventory_reason_code
        )
      end

      posting = Inventory::Post.call(
        store: buyback_void.store,
        posted_by_user: posted_by_user,
        posting_type: "buyback_void",
        source: buyback_void,
        lines: payloads,
        idempotency_key: "buyback-void-#{buyback_void.id}",
        workstation: buyback_void.workstation,
        reversal_of_posting: original_posting,
        notes: "Void of buyback #{session.buyback_number}"
      )

      buyback_void.update!(inventory_posting: posting)
      session.buyback_lines.where(status: "posted").find_each do |line|
        entry = posting.inventory_ledger_entries.find_by(product_variant_id: line.product_variant_id)
        line.update!(void_inventory_ledger_entry: entry, status: "voided") if entry
      end

      posting
    end

    private

    attr_reader :buyback_void, :posted_by_user, :session
  end
end
