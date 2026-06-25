# frozen_string_literal: true

module Inventory
  class Eligibility
    def self.eligible?(variant)
      new(variant).eligible?
    end

    def self.ensure_eligible!(variant)
      new(variant).ensure_eligible!
    end

    def self.eligible_for_pos_line?(line)
      tracking_input = line.inventory_tracking_snapshot.presence ||
        line.inventory_behavior_snapshot.presence ||
        line.product_variant
      TrackingResolver.inventory?(tracking_input)
    end

    def initialize(variant)
      @variant = variant
    end

    def eligible?
      TrackingResolver.inventory?(variant)
    end

    def ensure_eligible!
      return if eligible?

      tracking = TrackingResolver.resolve(variant)
      raise IneligibleVariantError,
        "Variant #{variant.sku} is not inventory-eligible " \
        "(tracking: #{tracking}, inventory_behavior: #{variant.inventory_behavior})"
    end

    private

    attr_reader :variant

    class IneligibleVariantError < StandardError; end
  end
end
