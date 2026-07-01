# frozen_string_literal: true

class SkuGenerator
  def self.product_sku(product)
    primary = product.primary_identifier
    if primary.present?
      primary.normalized_identifier
    elsif product.sku.present?
      product.sku
    else
      raise ArgumentError, "Product has no primary identifier"
    end
  end

  def self.variant_sku(product_variant)
    preview_variant_sku(
      product: product_variant.product,
      condition: product_variant.condition,
      attribute1_sku_component: product_variant.attribute1_sku_component,
      attribute2_sku_component: product_variant.attribute2_sku_component
    )
  end

  def self.preview_variant_sku(product:, condition: nil, attribute1_sku_component: nil, attribute2_sku_component: nil)
    base = product.sku.presence || product_sku(product)
    parts = []

    parts << condition.sku_component if condition&.sku_component.present?

    case product.variation_type
    when "variable"
      parts << attribute1_sku_component if attribute1_sku_component.present?
    when "matrix"
      parts.concat([ attribute1_sku_component, attribute2_sku_component ].compact_blank)
    end

    parts.compact_blank!
    return base if parts.empty?

    "#{base}-#{parts.join('-')}"
  end
end
