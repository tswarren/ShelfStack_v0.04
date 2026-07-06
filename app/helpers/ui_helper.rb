# frozen_string_literal: true

module UiHelper
  BUTTON_VARIANT_CLASSES = {
    primary: "ss-btn-primary",
    secondary: "ss-btn-secondary",
    tertiary: "ss-btn-tertiary",
    ghost: "ss-btn-ghost",
    danger: "ss-btn-danger",
    link: "ss-btn-link"
  }.freeze

  def ss_button_classes(variant: :primary, size: nil, full_width: false, icon: false, extra_class: nil)
    variant = variant.to_sym

    classes =
      if variant == :link
        [ "ss-btn-link" ]
      else
        [ "ss-btn", BUTTON_VARIANT_CLASSES.fetch(variant, "ss-btn-primary") ]
      end

    classes << "ss-btn--small" if size == :small
    classes << "ss-btn--large" if size == :large
    classes << "ss-btn--full" if full_width
    classes << "ss-btn--icon" if icon
    classes << extra_class if extra_class.present?

    classes.compact.join(" ")
  end

  def ss_alert_variant_class(variant)
    allowed = %i[info success warning error]
    key = variant.to_sym
    key = :info unless allowed.include?(key)

    "ss-alert--#{key}"
  end
end
