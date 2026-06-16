# frozen_string_literal: true

module Inventory
  class BalanceUpdater
    def self.apply!(store:, variant:, quantity_delta:, valuation:, posting:)
      new(store:, variant:, quantity_delta:, valuation:, posting:).apply!
    end

    def initialize(store:, variant:, quantity_delta:, valuation:, posting:)
      @store = store
      @variant = variant
      @quantity_delta = quantity_delta
      @valuation = valuation
      @posting = posting
    end

    def apply!
      balance = InventoryBalance.find_or_initialize_by(store: store, product_variant: variant)
      prior_on_hand = balance.quantity_on_hand || 0
      balance.quantity_on_hand = prior_on_hand + quantity_delta
      balance.quantity_available = balance.quantity_on_hand
      balance.unit_cost_cents = valuation.unit_cost_cents
      balance.unit_retail_cents = valuation.unit_retail_cents
      balance.cost_source = valuation.cost_source
      balance.retail_source = valuation.retail_source
      balance.last_posting = posting

      cost_delta = valuation.total_cost_cents || 0
      retail_delta = valuation.total_retail_cents || 0
      if quantity_delta.negative?
        balance.inventory_cost_value_cents = [ balance.inventory_cost_value_cents + cost_delta, 0 ].max
        balance.inventory_retail_value_cents = [ balance.inventory_retail_value_cents + retail_delta, 0 ].max
      else
        balance.inventory_cost_value_cents += cost_delta
        balance.inventory_retail_value_cents += retail_delta
      end

      balance.save!
      record_negative_transition!(balance, prior_on_hand)
      balance
    end

    private

    attr_reader :store, :variant, :quantity_delta, :valuation, :posting

    def record_negative_transition!(balance, prior_on_hand)
      return unless prior_on_hand >= 0 && balance.quantity_on_hand.negative?

      AuditEvents.record!(
        actor: posting.posted_by_user,
        event_name: "inventory_balance.negative",
        auditable: balance,
        details: {
          "store_id" => store.id,
          "product_variant_id" => variant.id,
          "quantity_on_hand" => balance.quantity_on_hand
        }
      )
    end
  end
end
