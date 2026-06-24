# frozen_string_literal: true

module Buybacks
  class PostInventory
    def self.call(session:, posted_by_user:)
      new(session:, posted_by_user:).call
    end

    def initialize(session:, posted_by_user:)
      @session = session
      @posted_by_user = posted_by_user
    end

    def call
      lines = session.buyback_lines.order(:line_number).select(&:accepted_for_posting?)
      return nil if lines.empty?

      payloads = lines.map do |line|
        variant = line.product_variant
        if line.accepted_resale_price_cents.present? &&
            VariantPricePolicy.updatable_from_buyback?(variant: variant, store: session.store, session: session)
          variant.update!(selling_price_cents: line.accepted_resale_price_cents)
        end

        cost_source = line.donation? ? "no_value_donation" : "buyback_offer"
        Inventory::Post::LinePayload.new(
          product_variant: variant,
          quantity_delta: line.quantity,
          movement_type: "used_buyback",
          manual_unit_cost_cents: line.accepted_offer_cents.to_i,
          cost_source: cost_source,
          inventory_location: nil,
          inventory_reason_code: nil
        )
      end

      posting = Inventory::Post.call(
        store: session.store,
        posted_by_user: posted_by_user,
        posting_type: "used_buyback",
        source: session,
        lines: payloads,
        idempotency_key: "buyback-session-#{session.id}",
        workstation: session.workstation,
        notes: "Buyback #{session.buyback_number}"
      )

      lines.each_with_index do |line, index|
        entry = posting.inventory_ledger_entries.find_by(line_number: index + 1)
        line.update!(inventory_ledger_entry: entry, status: "posted") if entry
      end

      session.update!(inventory_posting: posting)
      posting
    end

    private

    attr_reader :session, :posted_by_user
  end
end
