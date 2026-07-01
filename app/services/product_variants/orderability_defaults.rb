# frozen_string_literal: true

module ProductVariants
  class OrderabilityDefaults
    NON_ORDERABLE_PRODUCT_TYPES = %w[service financial].freeze

    def self.resolve(variant)
      new(variant).resolve
    end

    def self.apply!(variant)
      variant.orderable = resolve(variant)
      variant
    end

    def initialize(variant)
      @variant = variant
    end

    def resolve
      return false if variant.blank?
      return false if NON_ORDERABLE_PRODUCT_TYPES.include?(variant.product&.product_type)
      return false if ProductVariants::OperationalPolicy.for(variant).used_like?
      return false if non_inventory_without_explicit_orderable?

      true
    end

    private

    attr_reader :variant

    def non_inventory_without_explicit_orderable?
      variant.product&.product_type == "non_inventory"
    end
  end
end
