# frozen_string_literal: true

module Inventory
  class TrackingResolver
    INVENTORY_TRACKING = "inventory"
    NON_INVENTORY_TRACKING = "non_inventory"

    TRACKING_VALUES = [ INVENTORY_TRACKING, NON_INVENTORY_TRACKING ].freeze

    LEGACY_INVENTORY_BEHAVIORS = %w[standard_physical].freeze

    class UnknownTrackingValueError < StandardError; end

    def self.resolve(value)
      new(value).resolve
    end

    def self.inventory?(value)
      resolve(value) == INVENTORY_TRACKING
    end

    def self.resolve!(value)
      new(value, strict: true).resolve
    end

    def self.tracking_for_behavior(behavior)
      LEGACY_INVENTORY_BEHAVIORS.include?(behavior.to_s) ? INVENTORY_TRACKING : NON_INVENTORY_TRACKING
    end

    def initialize(value, strict: false)
      @value = value
      @strict = strict
    end

    def resolve
      case resolve_tracking
      when :invalid
        raise UnknownTrackingValueError, invalid_message if strict?

        NON_INVENTORY_TRACKING
      else
        resolve_tracking
      end
    end

    private

    attr_reader :value

    def strict?
      @strict
    end

    def resolve_tracking
      return :invalid if value.nil?

      if value.is_a?(ProductVariant)
        return resolve_variant(value)
      end

      string_value = value.to_s
      return INVENTORY_TRACKING if string_value == INVENTORY_TRACKING
      return NON_INVENTORY_TRACKING if string_value == NON_INVENTORY_TRACKING
      return tracking_for_behavior(string_value) if ProductVariant::INVENTORY_BEHAVIORS.include?(string_value)

      :invalid
    end

    def resolve_variant(variant)
      return variant.inventory_tracking_override if variant.inventory_tracking_override.present?

      if variant.inventory_behavior.present?
        return tracking_for_behavior(variant.inventory_behavior)
      end

      product = variant.product
      if product&.default_inventory_tracking.present?
        return product.default_inventory_tracking
      end

      AddItem::InventoryTrackingMapper.for_product_type(product&.product_type)
    end

    def tracking_for_behavior(behavior)
      self.class.tracking_for_behavior(behavior)
    end

    def invalid_message
      if value.nil?
        "Inventory tracking value is nil"
      else
        "Unknown inventory tracking value: #{value.inspect}"
      end
    end
  end
end
