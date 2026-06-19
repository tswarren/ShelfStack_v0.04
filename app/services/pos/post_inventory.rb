# frozen_string_literal: true

module Pos
  class PostInventory
    def self.call(transaction:, posted_by_user:)
      new(transaction:, posted_by_user:).call
    end

    def initialize(transaction:, posted_by_user:)
      @transaction = transaction
      @posted_by_user = posted_by_user
    end

    def call
      lines = eligible_lines
      return nil if lines.empty?

      payloads = lines.map do |line|
        quantity_delta = line.quantity
        movement_type = quantity_delta.positive? ? "sold" : "customer_return"

        Inventory::Post::LinePayload.new(
          product_variant: line.product_variant,
          quantity_delta: quantity_delta,
          movement_type: movement_type,
          manual_unit_cost_cents: nil,
          cost_source: nil,
          inventory_location: nil,
          inventory_reason_code: nil
        )
      end

      Inventory::Post.call(
        store: transaction.store,
        posted_by_user: posted_by_user,
        posting_type: "pos_transaction",
        source: transaction,
        lines: payloads,
        idempotency_key: "pos-transaction-#{transaction.id}",
        workstation: transaction.workstation
      )
    end

    def self.eligible_line?(line)
      return false unless line.product_variant_id.present?

      behavior = line.inventory_behavior_snapshot.presence || line.product_variant&.inventory_behavior
      return false unless behavior == "standard_physical"
      return false if line.return_line? && line.return_disposition.present? && line.return_disposition != "return_to_stock"

      true
    end

    private

    attr_reader :transaction, :posted_by_user

    def eligible_lines
      transaction.pos_transaction_lines.select { |line| self.class.eligible_line?(line) }
    end
  end
end
