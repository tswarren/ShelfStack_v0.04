# frozen_string_literal: true

module Purchasing
  class MovingAverageCost
    def self.apply!(balance:, prior_on_hand:, quantity_received:, unit_cost_cents:)
      new(balance:, prior_on_hand:, quantity_received:, unit_cost_cents:).apply!
    end

    def initialize(balance:, prior_on_hand:, quantity_received:, unit_cost_cents:)
      @balance = balance
      @prior_on_hand = prior_on_hand
      @quantity_received = quantity_received
      @unit_cost_cents = unit_cost_cents
    end

    def apply!
      return balance if unit_cost_cents.nil? || quantity_received <= 0

      if prior_on_hand <= 0 || balance.moving_average_unit_cost_cents.nil?
        balance.moving_average_unit_cost_cents = unit_cost_cents
      else
        prior_value = prior_on_hand * balance.moving_average_unit_cost_cents
        received_value = quantity_received * unit_cost_cents
        new_quantity = prior_on_hand + quantity_received
        balance.moving_average_unit_cost_cents = ((prior_value + received_value) / new_quantity.to_f).round
      end

      balance
    end

    private

    attr_reader :balance, :prior_on_hand, :quantity_received, :unit_cost_cents
  end
end
