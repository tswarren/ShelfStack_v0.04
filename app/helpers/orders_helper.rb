# frozen_string_literal: true

module OrdersHelper
  def orders_item_viewable?
    Authorization.allowed?(
      user: current_user,
      permission_key: "items.catalog_items.view",
      store: current_store
    )
  end

  def orders_item_path_for_variant(variant, tab: "overview")
    params = Items::ItemPresenter.from_product_variant(variant).route_params.merge(tab: tab)
    items_item_path(params)
  end

  def orders_variant_display_sku(variant, sku_snapshot: nil)
    sku_snapshot.presence || variant&.sku
  end

  def orders_variant_display_name(variant, name_snapshot: nil)
    name_snapshot.presence || variant&.name
  end

  def orders_variant_sku_link(variant, sku_snapshot: nil, tab: "overview")
    sku = orders_variant_display_sku(variant, sku_snapshot: sku_snapshot)
    return "—" if sku.blank?

    if variant.present? && orders_item_viewable?
      link_to sku, orders_item_path_for_variant(variant, tab: tab)
    else
      sku
    end
  end

  def orders_tbo_sourcing_path(variant, vendor:, from_tbo_filters: {})
    return nil if variant.blank? || vendor.blank?
    return nil unless Authorization.allowed?(
      user: current_user,
      permission_key: "setup.product_variant_vendors.create",
      store: current_store
    )

    new_items_product_variant_product_variant_vendor_path(
      variant,
      vendor_id: vendor.id,
      return_to: "from_tbo",
      from_tbo_view: from_tbo_filters[:view],
      from_tbo_vendor_id: from_tbo_filters[:vendor_id] || vendor.id,
      from_tbo_sourced_only: from_tbo_filters[:sourced_only],
      from_tbo_department_id: from_tbo_filters[:department_id],
      from_tbo_format_id: from_tbo_filters[:format_id]
    )
  end

  def orders_status_badge(status)
    css_class = orders_status_badge_class(status)
    tag.span(status.to_s.tr("_", " ").titleize, class: "ss-status-badge #{css_class}")
  end

  def orders_status_badge_class(status)
    case status.to_s
    when "draft", "open", "sourcing_needed"
      "status-draft"
    when "submitted", "posted", "added_to_po", "ready_to_order"
      "status-submitted"
    when "partially_received", "partially_ordered", "partially_received"
      "status-partial"
    when "cancelled", "closed", "credited"
      "status-cancelled"
    else
      "status-inactive"
    end
  end

  def orders_format_metric(value, format: :number)
    case format
    when :cents
      format_cents(value)
    when :bps
      format_basis_points(value)
    else
      value
    end
  end
end
