# frozen_string_literal: true

class SkuGenerator
  def self.product_sku(product)
    if product.catalog_item.present?
      primary = product.catalog_item.primary_identifier
      raise ArgumentError, "Catalog item has no primary identifier" if primary.blank?

      primary.normalized_identifier
    else
      product.sku
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
      parts.concat([attribute1_sku_component, attribute2_sku_component].compact_blank)
    end

    parts.compact_blank!
    return base if parts.empty?

    "#{base}-#{parts.join('-')}"
  end
end
