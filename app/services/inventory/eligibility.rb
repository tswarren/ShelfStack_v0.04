# frozen_string_literal: true

module Inventory
  class Eligibility
    def self.eligible?(variant)
      new(variant).eligible?
    end

    def self.ensure_eligible!(variant)
      new(variant).ensure_eligible!
    end

    def initialize(variant)
      @variant = variant
    end

    def eligible?
      variant.inventory_behavior == "standard_physical"
    end

    def ensure_eligible!
      return if eligible?

      raise IneligibleVariantError, "Variant #{variant.sku} is not inventory-eligible (#{variant.inventory_behavior})"
    end

    private

    attr_reader :variant

    class IneligibleVariantError < StandardError; end
  end
end
