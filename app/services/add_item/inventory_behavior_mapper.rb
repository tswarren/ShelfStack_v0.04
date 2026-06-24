# frozen_string_literal: true

module AddItem
  class InventoryBehaviorMapper
    PRODUCT_TYPE_DEFAULTS = {
      "physical" => "standard_physical",
      "digital" => "digital_asset",
      "service" => "capacitated_service",
      "financial" => "pure_financial",
      "non_inventory" => "non_inventory"
    }.freeze

    NON_INVENTORY_BEHAVIORS = {
      "physical" => "non_inventory",
      "digital" => "digital_asset",
      "service" => "capacitated_service",
      "financial" => "pure_financial",
      "non_inventory" => "non_inventory"
    }.freeze

    def self.for_product_type(product_type)
      PRODUCT_TYPE_DEFAULTS.fetch(product_type.to_s, "standard_physical")
    end

    def self.non_inventory_behavior_for_product_type(product_type)
      NON_INVENTORY_BEHAVIORS.fetch(product_type.to_s, "non_inventory")
    end
  end
end
