# frozen_string_literal: true

class VariantClassificationSetup
  def self.apply!(variant:)
    new(variant: variant).apply!
  end

  def initialize(variant:)
    @variant = variant
  end

  def apply!
    apply_sub_department!
    apply_display_location!
    variant
  end

  private

  attr_reader :variant

  def apply_sub_department!
    return if variant.sub_department.present?

    suggestion = SubDepartmentSuggestion.for(product: variant.product, condition: variant.condition)
    variant.sub_department = suggestion.sub_department if suggestion.sub_department.present?
  end

  def apply_display_location!
    return if variant.display_location.present?

    variant.display_location = variant.product.default_display_location ||
                               variant.product.catalog_item&.store_category&.default_display_location
  end
end
