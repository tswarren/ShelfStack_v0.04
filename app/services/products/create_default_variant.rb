# frozen_string_literal: true

module Products
  # Creates the single standard default variant for Service / Non-Inventory primary save.
  class CreateDefaultVariant
    Result = Struct.new(:success?, :variant, :errors, keyword_init: true)

    def self.call(product:)
      new(product: product).call
    end

    def initialize(product:)
      @product = product
    end

    def call
      errors = []
      if @product.default_sub_department_id.blank?
        errors << "Subdepartment is required before creating the default variant."
      end
      return failure(errors) if errors.any?

      variant = ProductVariant.new(
        product: @product,
        active: true,
        selling_price_cents: @product.list_price_cents.to_i,
        sub_department_id: @product.default_sub_department_id,
        display_location_id: @product.default_display_location_id,
        preferred_vendor_id: @product.preferred_vendor_id,
        discountable: @product.discountable
      )
      Items::InventoryTrackingSync.seed_defaults_from_product!(variant: variant)
      VariantClassificationSetup.apply!(variant: variant)

      if variant.save
        Result.new(success?: true, variant: variant, errors: [])
      else
        failure(variant.errors.full_messages)
      end
    end

    private

    def failure(errors)
      Result.new(success?: false, variant: nil, errors: Array(errors))
    end
  end
end
