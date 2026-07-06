# frozen_string_literal: true

module ApplicationHelper
  include SetupFormatHelper
  include ItemsHelper
  include FormHelper
  include ReportsHelper

  APPEARANCE_VIEW_MODE_LABELS = {
    "standard" => "Standard View",
    "accessible" => "Accessible View",
    "compact" => "Compact View"
  }.freeze

  FLASH_COMPONENT_VARIANTS = {
    notice: "success",
    success: "success",
    warning: "warning",
    alert: "error",
    error: "error"
  }.freeze

  def display_time(timestamp)
    return "—" if timestamp.blank?

    timestamp.in_time_zone(Current.time_zone).strftime("%Y-%m-%d %H:%M %Z")
  end

  def status_label(active)
    active ? "Active" : "Inactive"
  end

  def status_class(active)
    active ? "status-active" : "status-inactive"
  end

  def session_status_label(status)
    status.to_s.humanize
  end

  def shelfstack_appearance_attributes
    {
      data: {
        ss_typeface: shelfstack_typeface_profile,
        ss_density: shelfstack_density_profile,
        ss_color_mode: shelfstack_color_mode
      }
    }
  end

  def shelfstack_body_attributes(*class_names)
    attributes = shelfstack_appearance_attributes
    body_classes = [ "ss-app-body" ]
    body_classes << content_for(:body_class) if content_for?(:body_class)
    body_classes.concat(class_names)

    attributes[:class] = shelfstack_class_names(body_classes)
    attributes
  end

  def shelfstack_class_names(*class_names)
    class_names.flatten.compact.flat_map { |class_name| class_name.to_s.split(/\s+/) }.reject(&:blank?).uniq.join(" ")
  end

  def shelfstack_nav_item_class(active: false, disabled: false)
    shelfstack_class_names(
      "ss-nav__item",
      active && "ss-nav__item--active",
      disabled && "ss-nav__item--disabled"
    )
  end

  def shelfstack_flash_variant(key)
    FLASH_COMPONENT_VARIANTS.fetch(key.to_sym, "info")
  end

  def shelfstack_flash_class(key)
    variant = shelfstack_flash_variant(key)
    shelfstack_class_names("ss-flash", "ss-alert", "ss-alert--#{variant}", "ss-flash--#{variant}")
  end

  def shelfstack_view_mode
    current_user&.appearance_view_mode.presence || "standard"
  end

  def shelfstack_view_mode_label(mode = shelfstack_view_mode)
    APPEARANCE_VIEW_MODE_LABELS.fetch(mode.to_s, APPEARANCE_VIEW_MODE_LABELS.fetch("standard"))
  end

  def shelfstack_typeface_profile
    current_user&.appearance_typeface || "atkinson"
  end

  def shelfstack_density_profile
    current_user&.appearance_density || "standard"
  end

  def shelfstack_color_mode
    current_user&.appearance_color_mode.presence || "light"
  end

  def audit_event_details_summary(event)
    details = event.event_details
    return "—" if details.blank?

    if details["changes"].present?
      details["changes"].map do |field, change|
        "#{field}: #{change['from'].inspect} → #{change['to'].inspect}"
      end.join("; ")
    elsif details["attributes"].present?
      details["attributes"].map { |field, value| "#{field}: #{value.inspect}" }.join("; ")
    else
      details.map { |field, value| "#{field}: #{value.inspect}" }.join("; ")
    end
  end

  def role_assignment_scope_label(assignment)
    if assignment.global_scoped?
      "Global"
    else
      store = assignment.store
      store ? "#{store.name} (#{store.store_number})" : "Store"
    end
  end
end
