# frozen_string_literal: true

module ItemsHelper
  include SetupFormatHelper
  USER_FACING_LABELS = {
    "catalog_items" => "Item Details",
    "products" => "Selling Setup",
    "product_variants" => "Sellable SKUs",
    "catalog_item_identifiers" => "Barcodes and Identifiers",
    "product_conditions" => "Conditions",
    "display_locations" => "Shelf/Display Locations"
  }.freeze

  def items_user_facing_label(resource_key)
    USER_FACING_LABELS.fetch(resource_key.to_s) { resource_key.to_s.tr("_", " ").titleize }
  end

  def item_lifecycle_status_badge(status)
    css_class = case status.to_s
                when "sellable" then "status-active"
                when "catalog_only", "product_created", "no_active_variant" then "status-inactive"
                when "invalid_identifier_warning", "missing_sub_department", "missing_store_category", "missing_price", "inactive_setup_reference" then "status-warning"
                else "status-inactive"
                end

    tag.span(status.to_s.tr("_", " ").titleize, class: "ss-status-badge #{css_class}")
  end

  COVER_IMAGE_SIZES = {
    hero: [112, 160],
    search: [48, 70],
    index: [40, 58]
  }.freeze

  def product_cover_image_representation(attachment, size: :hero)
    return unless attachment&.attached?

    return attachment if attachment.blob.content_type == "image/gif"

    attachment.variant(resize_to_limit: COVER_IMAGE_SIZES.fetch(size))
  end

  def product_cover_image_tag(attachment, size: :hero, alt: "Cover image")
    if attachment&.attached?
      image_tag product_cover_image_representation(attachment, size: size),
                class: "ss-item-cover-image ss-item-cover-image--#{size}",
                alt: alt
    else
      item_cover_placeholder(size: size)
    end
  end

  def item_cover_thumbnail(item, size: :hero)
    product_cover_image_tag(
      item.product&.cover_image,
      size: size,
      alt: "Cover image for #{item.title}"
    )
  end

  def item_cover_placeholder(size: :hero)
    tag.div(class: "ss-item-cover ss-item-cover-placeholder ss-item-cover--#{size}", aria: { hidden: true }) do
      tag.span("Cover", class: "ss-item-cover-label")
    end
  end

  def item_creator_role_badge(role)
    tag.span(humanize_controlled_value(role), class: "ss-status-badge ss-creator-role-badge")
  end

  def item_publication_status_badge(status_label)
    tag.span(status_label, class: "ss-status-badge status-active")
  end

  def identifier_primary_badge
    tag.span("Primary", class: "ss-status-badge status-active")
  end

  def identifier_invalid_badge
    tag.span("Invalid identifier", class: "ss-status-badge status-warning")
  end

  def item_location_eyebrow(locations, topic_section: nil)
    return if locations.blank? && topic_section.blank?

    tag.nav(class: "ss-item-location-eyebrow", aria: { label: "Display location and topic" }) do
      parts = []

      if locations.present?
        parts << safe_join(locations.each_with_index.flat_map do |location, index|
          crumbs = []
          crumbs << tag.span("›", class: "ss-item-location-sep", aria: { hidden: true }) if index.positive?
          crumbs << tag.span(location.name, class: "ss-item-location-crumb")
          crumbs
        end)
      end

      if topic_section.present?
        parts << tag.span("·", class: "ss-item-location-sep", aria: { hidden: true }) if parts.any?
        parts << tag.span(topic_section, class: "ss-item-location-crumb ss-item-topic-crumb")
      end

      safe_join(parts)
    end
  end

  DESCRIPTION_PREVIEW_LENGTH = 280

  def item_description_block(text, length: DESCRIPTION_PREVIEW_LENGTH)
    return if text.blank?

    if text.length > length
      tag.details(class: "ss-item-description") do
        safe_join([
          tag.summary(class: "ss-item-description-summary") do
            safe_join([
              tag.span(truncate(text, length: length, separator: " "), class: "ss-item-description-teaser"),
              tag.span("Read more", class: "ss-item-read-more")
            ])
          end,
          tag.div(simple_format(text), class: "ss-item-description-body")
        ])
      end
    else
      tag.div(simple_format(text), class: "ss-item-description")
    end
  end

  def item_flow?
    params[:return_to].to_s == "item"
  end

  def item_flow_cancel_path(record, tab: nil, variant_id: nil)
    Items::ReturnPath.for(
      record: record,
      return_to: params[:return_to].presence || "item",
      tab: tab,
      variant_id: variant_id
    )
  end

  def item_flow_path_options
    item_flow? ? { return_to: "item" } : {}
  end
end
