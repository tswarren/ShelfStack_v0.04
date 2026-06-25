# frozen_string_literal: true

module Items
  class InventoryTrackingSync
    Preview = Data.define(:previous_tracking, :new_tracking, :previous_eligible, :new_eligible)

    def self.apply_tracking_selection!(variant:, tracking:)
      new(variant:, tracking:).apply_tracking_selection!
    end

    def self.apply_legacy_behavior_edit!(variant:, inventory_behavior:)
      new(variant:, inventory_behavior:).apply_legacy_behavior_edit!
    end

    def self.preview_legacy_behavior_edit(variant:, inventory_behavior:)
      new(variant:, inventory_behavior:).preview_legacy_behavior_edit
    end

    def initialize(variant:, tracking: nil, inventory_behavior: nil)
      @variant = variant
      @tracking = tracking
      @inventory_behavior = inventory_behavior
    end

    def apply_tracking_selection!
      tracking = @tracking.to_s
      raise ArgumentError, "Invalid inventory tracking." unless Inventory::TrackingResolver::TRACKING_VALUES.include?(tracking)

      variant.inventory_tracking_override = tracking
      variant.inventory_behavior = legacy_behavior_for_tracking(tracking)
      variant
    end

    def apply_legacy_behavior_edit!
      variant.inventory_tracking_override = nil
      variant.inventory_behavior = @inventory_behavior
      variant
    end

    def preview_legacy_behavior_edit
      previous_tracking = Inventory::TrackingResolver.resolve(variant)
      previous_eligible = Inventory::Eligibility.eligible?(variant)

      temp = variant.dup
      temp.id = variant.id
      temp.inventory_tracking_override = nil
      temp.inventory_behavior = @inventory_behavior

      new_tracking = Inventory::TrackingResolver.resolve(temp)
      new_eligible = Inventory::Eligibility.eligible?(temp)

      Preview.new(
        previous_tracking: previous_tracking,
        new_tracking: new_tracking,
        previous_eligible: previous_eligible,
        new_eligible: new_eligible
      )
    end

    def self.seed_defaults_from_product!(variant:)
      new(variant:).seed_defaults_from_product!
    end

    def seed_defaults_from_product!
      product = variant.product
      return variant if product.blank?

      tracking = product.default_inventory_tracking.presence ||
        AddItem::InventoryTrackingMapper.for_product_type(product.product_type)

      variant.inventory_behavior = if tracking == Inventory::TrackingResolver::INVENTORY_TRACKING
        "standard_physical"
      else
        AddItem::InventoryBehaviorMapper.non_inventory_behavior_for_product_type(product.product_type)
      end
      variant
    end

    private

    attr_reader :variant

    def legacy_behavior_for_tracking(tracking)
      if tracking == Inventory::TrackingResolver::INVENTORY_TRACKING
        "standard_physical"
      else
        AddItem::InventoryBehaviorMapper.non_inventory_behavior_for_product_type(variant.product.product_type)
      end
    end
  end
end
