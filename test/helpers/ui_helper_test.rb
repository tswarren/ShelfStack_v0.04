# frozen_string_literal: true

require "test_helper"

class UiHelperTest < ActionView::TestCase
  include UiHelper

  test "ss_button_classes primary and danger variants" do
    assert_equal "ss-btn ss-btn-primary", ss_button_classes(variant: :primary)
    assert_equal "ss-btn ss-btn-danger", ss_button_classes(variant: :danger)
  end

  test "ss_button_classes link variant uses ss-btn-link only" do
    assert_equal "ss-btn-link", ss_button_classes(variant: :link)
  end

  test "ss_button_classes supports size and full width modifiers" do
    assert_equal "ss-btn ss-btn-secondary ss-btn--small ss-btn--full",
      ss_button_classes(variant: :secondary, size: :small, full_width: true)
  end

  test "ss_alert_variant_class allows documented variants only" do
    assert_equal "ss-alert--warning", ss_alert_variant_class(:warning)
    assert_equal "ss-alert--error", ss_alert_variant_class(:error)
    assert_equal "ss-alert--info", ss_alert_variant_class(:neutral)
  end

  test "ss_status_badge preserves underscore status keys" do
    html = ss_status_badge("Partially received", status: :partially_received)

    assert_includes html, "ss-status-badge"
    assert_includes html, "status-partially_received"
    assert_not_includes html, "status-partially-received"
  end
end
