# frozen_string_literal: true

class ProductNameRenderer
  def self.product_name(product)
    return product.name_override if product.name_override.present?
    return product.catalog_item.title if product.catalog_item.present?

    product.name
  end

  def self.variant_name(variant)
    return variant.name_override if variant.name_override.present?

    base = variant.product.name
    product = variant.product

    case product.variation_type
    when "standard"
      base
    when "conditional"
      return base if variant.condition.blank?

      "#{base} - #{variant.condition.short_name}"
    when "variable"
      return base if variant.attribute1_value.blank?

      "#{base} - #{variant.attribute1_value}"
    when "matrix"
      if variant.attribute1_value.present? && variant.attribute2_value.present?
        "#{base} - #{variant.attribute1_value} / #{variant.attribute2_value}"
      elsif variant.attribute1_value.present?
        "#{base} - #{variant.attribute1_value}"
      elsif variant.condition.present?
        "#{base} - #{variant.condition.short_name}"
      else
        base
      end
    else
      base
    end
  end
end
