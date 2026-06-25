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
      balance.quantity_reserved ||= 0
      balance.quantity_available = balance.quantity_on_hand - balance.quantity_reserved
      balance.unit_cost_cents = valuation.unit_cost_cents
      balance.unit_retail_cents = valuation.unit_retail_cents
      balance.cost_source = valuation.cost_source
      balance.retail_source = valuation.retail_source
      balance.last_posting = posting

      cost_delta = valuation.total_cost_cents || 0
      retail_delta = valuation.total_retail_cents || 0
      if quantity_delta.negative?
        balance.inventory_cost_value_cents = [ balance.inventory_cost_value_cents - cost_delta, 0 ].max
        balance.inventory_retail_value_cents = [ balance.inventory_retail_value_cents - retail_delta, 0 ].max
      else
        balance.inventory_cost_value_cents += cost_delta
        balance.inventory_retail_value_cents += retail_delta
      end

      if valuation.cost_source.in?(%w[receipt_cost buyback_offer no_value_donation]) && quantity_delta.positive?
        Purchasing::MovingAverageCost.apply!(
          balance: balance,
          prior_on_hand: prior_on_hand,
          quantity_received: quantity_delta,
          unit_cost_cents: valuation.unit_cost_cents
        )
      end

      balance.save!
      record_negative_transitions!(balance, prior_on_hand)
      balance
    end

    private

    attr_reader :store, :variant, :quantity_delta, :valuation, :posting

    def record_negative_transitions!(balance, prior_on_hand)
      new_on_hand = balance.quantity_on_hand

      if prior_on_hand >= 0 && new_on_hand.negative?
        record_balance_audit!("inventory_balance.negative", balance, new_on_hand)
      elsif prior_on_hand.negative? && new_on_hand >= 0
        record_balance_audit!("inventory_balance.cleared_negative", balance, new_on_hand)
      end
    end

    def record_balance_audit!(event_name, balance, quantity_on_hand)
      AuditEvents.record!(
        actor: posting.posted_by_user,
        event_name: event_name,
        auditable: balance,
        details: {
          "store_id" => store.id,
          "product_variant_id" => variant.id,
          "quantity_on_hand" => quantity_on_hand
        }
      )
    end
  end
end
