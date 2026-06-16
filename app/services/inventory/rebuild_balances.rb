# frozen_string_literal: true

module Inventory
  class RebuildBalances
    def self.call(actor: nil)
      new(actor:).call
    end

    def initialize(actor: nil)
      @actor = actor
    end

    def call
      rebuilt = 0
      InventoryBalance.delete_all

      ledger_sums.each do |row|
        variant = ProductVariant.find(row.product_variant_id)
        store = Store.find(row.store_id)
        last_entry = InventoryLedgerEntry
          .where(store_id: row.store_id, product_variant_id: row.product_variant_id)
          .order(occurred_at: :desc, id: :desc)
          .first

        valuation = CostEstimator.estimate(
          variant: variant,
          quantity_delta: row.total_delta,
          manual_unit_cost_cents: last_entry&.unit_cost_cents
        )

        InventoryBalance.create!(
          store: store,
          product_variant: variant,
          quantity_on_hand: row.total_delta,
          quantity_available: row.total_delta,
          inventory_cost_value_cents: sum_total_cost(row.store_id, row.product_variant_id),
          inventory_retail_value_cents: sum_total_retail(row.store_id, row.product_variant_id),
          unit_cost_cents: last_entry&.unit_cost_cents,
          unit_retail_cents: last_entry&.unit_retail_cents,
          cost_source: last_entry&.cost_source,
          retail_source: last_entry&.retail_source,
          last_posting_id: last_entry&.inventory_posting_id
        )
        rebuilt += 1
      end

      AuditEvents.record!(
        actor: actor || User.find_by!(username: ShelfStack::SYSTEM_USERNAME),
        event_name: "inventory.balance_rebuild",
        details: { "balances_rebuilt" => rebuilt }
      )

      rebuilt
    end

    private

    attr_reader :actor

    def ledger_sums
      InventoryLedgerEntry
        .select("store_id, product_variant_id, SUM(quantity_delta) AS total_delta")
        .group(:store_id, :product_variant_id)
    end

    def sum_total_cost(store_id, variant_id)
      InventoryLedgerEntry
        .where(store_id: store_id, product_variant_id: variant_id)
        .sum(:total_cost_cents) || 0
    end

    def sum_total_retail(store_id, variant_id)
      InventoryLedgerEntry
        .where(store_id: store_id, product_variant_id: variant_id)
        .sum(:total_retail_cents) || 0
    end
  end
end
