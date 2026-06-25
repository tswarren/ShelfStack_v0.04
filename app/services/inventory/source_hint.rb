# frozen_string_literal: true

module Inventory
  class SourceHint
    ACQUISITION_MOVEMENTS = %w[
      received used_buyback opening_balance transfer_in manual_adjustment correction recount_adjustment
    ].freeze

    HINT_LABELS = {
      "received" => "Supplier",
      "used_buyback" => "Trade-in",
      "opening_balance" => "Opening balance",
      "transfer_in" => "Transfer",
      "manual_adjustment" => "Adjustment",
      "correction" => "Adjustment",
      "recount_adjustment" => "Adjustment"
    }.freeze

    Result = Data.define(:label, :movement_type, :authoritative)

    def self.for(variant:, store:)
      new(variant:, store:).call
    end

    def initialize(variant:, store:)
      @variant = variant
      @store = store
    end

    def call
      entry = acquisition_entry
      if entry
        return Result.new(
          label: HINT_LABELS.fetch(entry.movement_type, "Adjustment"),
          movement_type: entry.movement_type,
          authoritative: false
        )
      end

      if variant.condition&.buyback_eligible?
        return Result.new(label: "Usually trade-in", movement_type: nil, authoritative: false)
      end

      Result.new(label: "Not yet stocked", movement_type: nil, authoritative: false)
    end

    private

    attr_reader :variant, :store

    def acquisition_entry
      scope = InventoryLedgerEntry
        .where(store: store, product_variant: variant)
        .where(movement_type: ACQUISITION_MOVEMENTS)
        .order(occurred_at: :desc, id: :desc)

      scope.find { |entry| acquisition_quantity?(entry) }
    end

    def acquisition_quantity?(entry)
      return entry.quantity_delta.positive? if entry.movement_type == "manual_adjustment"

      entry.quantity_delta.positive?
    end
  end
end
