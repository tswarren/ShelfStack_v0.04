# frozen_string_literal: true

module DemandLines
  class CreateConfirmationMessage
    def self.for(demand_line:, allocation_result: nil)
      new(demand_line:, allocation_result:).call
    end

    def initialize(demand_line:, allocation_result: nil)
      @demand_line = demand_line
      @allocation_result = allocation_result
    end

    def call
      case demand_line.capture_intent
      when "hold"
        hold_message
      when "notify"
        "Notify request recorded; customer will appear in the notify queue when stock is available."
      when "special_order"
        "Special order recorded; no supply allocated yet."
      when "manual_tbo"
        "Manual TBO recorded for buyer review."
      when "buyer_replenishment"
        "Buyer replenishment demand recorded."
      when "used_wanted"
        "Used wanted demand recorded."
      when "research"
        "Research demand recorded; match a variant to continue."
      else
        "Demand recorded."
      end
    end

    private

    attr_reader :demand_line, :allocation_result

    def hold_message
      case allocation_result
      when :full
        "Hold recorded and #{demand_line.quantity_requested} #{'copy'.pluralize(demand_line.quantity_requested)} allocated on hand."
      when :partial
        qty = demand_line.demand_allocations.active_allocations.on_hand_kind.sum(:quantity_allocated)
        "Hold recorded; #{qty} of #{demand_line.quantity_requested} allocated on hand."
      else
        "Hold recorded; no on-hand stock was available to allocate."
      end
    end
  end
end
