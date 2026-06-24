# frozen_string_literal: true

module AddItem
  class InventoryTrackingMapper
    PRODUCT_TYPE_DEFAULTS = {
      "physical" => Inventory::TrackingResolver::INVENTORY_TRACKING,
      "digital" => Inventory::TrackingResolver::NON_INVENTORY_TRACKING,
      "service" => Inventory::TrackingResolver::NON_INVENTORY_TRACKING,
      "financial" => Inventory::TrackingResolver::NON_INVENTORY_TRACKING,
      "non_inventory" => Inventory::TrackingResolver::NON_INVENTORY_TRACKING
    }.freeze

    def self.for_product_type(product_type)
      PRODUCT_TYPE_DEFAULTS.fetch(product_type.to_s, Inventory::TrackingResolver::INVENTORY_TRACKING)
    end
  end
end
