# frozen_string_literal: true

module Pos
  class PostVoidInventory
    def self.call(pos_void:, posted_by_user:)
      new(pos_void:, posted_by_user:).call
    end

    def initialize(pos_void:, posted_by_user:)
      @pos_void = pos_void
      @posted_by_user = posted_by_user
      @transaction = pos_void.pos_transaction
    end

    def call
      original_posting = transaction.inventory_posting
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

      Inventory::Post.call(
        store: pos_void.store,
        posted_by_user: posted_by_user,
        posting_type: "pos_void",
        source: pos_void,
        lines: payloads,
        idempotency_key: "pos-void-#{pos_void.id}",
        workstation: pos_void.workstation,
        reversal_of_posting: original_posting,
        notes: "Void of transaction #{transaction.transaction_number}"
      )
    end

    private

    attr_reader :pos_void, :posted_by_user, :transaction
  end
end
