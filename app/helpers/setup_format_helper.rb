# frozen_string_literal: true

module SetupFormatHelper
  def format_basis_points(bps)
    return "—" if bps.nil?

    format("%.2f%%", bps / 100.0)
  end

  def normalized_department_number_preview(value)
    return "—" if value.blank?

    stripped = value.to_s.strip
    return stripped unless stripped.match?(/\A\d+\z/)

    numeric = stripped.to_i
    return stripped if numeric.negative? || numeric > 999

    format("%03d", numeric)
  end

  def format_cents(cents)
    return "—" if cents.nil?

    format("$%.2f", cents / 100.0)
  end

  def identifier_normalization_preview(identifier_type, value)
    return "—" if value.blank?

    CatalogIdentifierService.normalize_preview(identifier_type, value)
  end

  def variant_sku_preview(product, condition: nil, attribute1_sku_component: nil, attribute2_sku_component: nil)
    return "—" if product.blank? || product.sku.blank?

    SkuGenerator.preview_variant_sku(
      product: product,
      condition: condition,
      attribute1_sku_component: attribute1_sku_component,
      attribute2_sku_component: attribute2_sku_component
    )
  end

  def humanize_controlled_value(value)
    value.to_s.tr("_", " ").titleize
  end

  def metadata_creators_preview(value)
    entries = MetadataParser.parse_creators(value)
    return "—" if entries.empty?

    entries.map { |entry| entry["display_name"] }.join("; ")
  end

  def metadata_subjects_preview(value)
    entries = MetadataParser.parse_subjects(value)
    return "—" if entries.empty?

    entries.map { |entry| entry["heading"] }.join("; ")
  end
end
