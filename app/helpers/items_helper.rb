# frozen_string_literal: true

module ItemsHelper
  include SetupFormatHelper

  USER_FACING_LABELS = {
    "catalog_items" => "Item metadata",
    "products" => "Selling Setup",
    "product_variants" => "Sellable SKUs",
    "product_identifiers" => "Barcodes and Identifiers",
    "product_conditions" => "Conditions",
    "display_locations" => "Shelf/Display Locations"
  }.freeze

  ITEM_TAB_LABELS = {
    "overview" => "Overview",
    "operations" => "Operations",
    "item_setup" => "Item setup",
    "activity" => "Activity"
  }.freeze

  COVER_IMAGE_SIZES = {
    hero: [ 112, 160 ],
    search: [ 48, 70 ],
    index: [ 40, 58 ]
  }.freeze

  CATALOG_ITEM_PLACEHOLDER_IMAGES = {
    "audiobook" => "audiobook.png",
    "book" => "book.png",
    "cafe" => "cafe.png",
    "calendar" => "calendar.png",
    "ebook" => "ebook.png",
    "game" => "game.png",
    "gift" => "gift_sideline.png",
    "map" => "map.png",
    "other" => "other.png",
    "periodical" => "periodical.png",
    "recorded_music" => "music.png",
    "sideline" => "gift_sideline.png",
    "videorecording" => "video.png"
  }.freeze

  def items_tab_label(tab)
    ITEM_TAB_LABELS.fetch(tab.to_s, tab.to_s.titleize)
  end

  def items_user_facing_label(resource_key)
    USER_FACING_LABELS.fetch(resource_key.to_s) { resource_key.to_s.tr("_", " ").titleize }
  end

  def item_lifecycle_status_badge(status)
    css_class = case status.to_s
    when "sellable" then "status-active"
    when "needs_product", "product_created", "no_active_variant" then "status-inactive"
    when "invalid_identifier_warning", "missing_sub_department", "missing_store_category", "missing_price", "inactive_setup_reference" then "status-warning"
    else "status-inactive"
    end

    tag.span(status.to_s.tr("_", " ").titleize, class: "ss-status-badge #{css_class}")
  end

  def product_cover_image_representation(attachment, size: :hero)
    return unless attachment&.attached?

    return attachment if attachment.blob.content_type == "image/gif"

    attachment.variant(resize_to_limit: COVER_IMAGE_SIZES.fetch(size))
  end

  def product_cover_image_tag(attachment, size: :hero, alt: "Cover image", item: nil)
    if attachment&.attached?
      image_tag product_cover_image_representation(attachment, size: size),
                class: "ss-item-cover-image ss-item-cover-image--#{size}",
                alt: alt
    else
      item_cover_placeholder(item: item, size: size)
    end
  end

  def item_cover_thumbnail(item, size: :hero)
    resolved = Items::ThumbnailResolver.resolve(item:)
    product_cover_image_tag(
      resolved.attachment,
      size: size,
      alt: "Cover image for #{item.title}",
      item: item
    )
  end

  def item_warning_severity_badge(severity)
    return if severity.blank?

    css_class = case severity.to_sym
    when :blocking then "status-warning"
    when :warning then "status-warning"
    else "status-inactive"
    end

    tag.span(severity.to_s.humanize, class: "ss-status-badge #{css_class}")
  end

  def item_vendor_source_status_label(status)
    case status.to_sym
    when :present then tag.span("Yes", class: "ss-status-badge status-active")
    when :warning then tag.span("Missing source", class: "ss-status-badge status-warning")
    when :not_applicable then tag.span("—", class: "ss-muted")
    else tag.span("No", class: "ss-status-badge status-inactive")
    end
  end

  def item_cover_placeholder(item: nil, size: :hero)
    image_tag(
      catalog_item_placeholder_image_path(item),
      class: "ss-item-cover-image ss-item-cover-image--#{size} ss-item-cover-placeholder-image",
      alt: catalog_item_placeholder_alt(item)
    )
  end

  def catalog_item_placeholder_image_path(item)
    catalog_item_type = item&.product&.catalog_item_type || item&.catalog_item&.catalog_item_type
    filename = CATALOG_ITEM_PLACEHOLDER_IMAGES.fetch(catalog_item_type, "other.png")

    "placeholders/catalog/#{filename}"
  end

  def catalog_item_placeholder_alt(item)
    catalog_item_type = item&.product&.catalog_item_type || item&.catalog_item&.catalog_item_type

    if catalog_item_type.present?
      "#{catalog_item_type.humanize} placeholder image"
    else
      "Generic product placeholder image"
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

  def product_identifier_display_type(identifier)
    identifier.validation_family
  end

  def product_identifier_legacy_type(identifier)
    return "isbn13" if identifier.blank?

    case identifier.validation_family
    when "isbn" then "isbn10"
    when "gtin" then "isbn13"
    when "freeform"
      identifier.freeform_scope == "publisher_number" ? "publisher_number" : "local"
    when "house" then "ean"
    else identifier.validation_family
    end
  end

  def product_identifier_barcode_safe?(identifier)
    return false unless identifier.is_a?(ProductIdentifier)

    identifier.validation_family.in?(%w[gtin house])
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
    if item_flow?
      { return_to: "item" }
    elsif request_match_context.valid?
      request_match_context.param_hash
    else
      {}
    end
  end

  def request_match_context
    @request_match_context ||= DemandLines::MatchContext.from_params(params, store: current_store)
  end

  def request_match_path_options
    request_match_context.valid? ? request_match_context.param_hash : {}
  end

  def request_match_banner_label
    request_match_context.banner_label if request_match_context.valid?
  end

  def items_item_path_with_match(item, tab: nil, variant_id: nil)
    params = item.route_params.merge(request_match_path_options)
    params[:tab] = tab if tab.present? && tab != "overview"
    params[:variant_id] = variant_id if variant_id.present?
    items_item_path(params)
  end

  def item_vendor_sourcing_editable?
    return false unless current_store.present?

    Authorization.allowed?(user: current_user, permission_key: "setup.product_vendors.create", store: current_store) ||
      Authorization.allowed?(user: current_user, permission_key: "setup.product_vendors.update", store: current_store) ||
      Authorization.allowed?(user: current_user, permission_key: "setup.product_variant_vendors.create", store: current_store) ||
      Authorization.allowed?(user: current_user, permission_key: "setup.product_variant_vendors.update", store: current_store)
  end

  def item_vendor_sourcing_path(variant)
    Items::VendorSourcingPath.for(variant)
  end

  def inventory_source_hint_label(source_hint)
    source_hint.movement_type.present? ? "Last stock source" : "Stock source hint"
  end
end
