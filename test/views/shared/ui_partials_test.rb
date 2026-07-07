# frozen_string_literal: true

require "test_helper"

class SharedUiPartialsTest < ActionView::TestCase
  include UiHelper

  test "button partial renders primary classes" do
    html = render(partial: "shared/ui/button", locals: { label: "Save", variant: :primary })

    assert_includes html, "ss-btn"
    assert_includes html, "ss-btn-primary"
    assert_includes html, "Save"
  end

  test "button partial renders danger classes" do
    html = render(partial: "shared/ui/button", locals: { label: "Delete", variant: :danger })

    assert_includes html, "ss-btn-danger"
  end

  test "button partial link variant uses ss-btn-link only" do
    html = render(partial: "shared/ui/button", locals: { label: "Cancel", variant: :link, url: "/setup" })

    assert_includes html, "ss-btn-link"
    assert_not_includes html, "ss-btn-primary"
    assert_includes html, 'href="/setup"'
  end

  test "button partial disabled link uses non-link element with aria-disabled" do
    html = render(partial: "shared/ui/button", locals: { label: "Next", url: "/setup", disabled: true })

    assert_includes html, "<span"
    assert_includes html, 'aria-disabled="true"'
    assert_not_includes html, "<a "
  end

  test "button partial defaults inline form class for non-get button_to" do
    html = render(
      partial: "shared/ui/button",
      locals: { label: "Inactivate", variant: :secondary, url: "/setup/vendors/1", method: :patch }
    )

    assert_includes html, 'class="ss-inline-form"'
    assert_includes html, "ss-btn-secondary"
  end

  test "page_header partial renders h1 and page actions" do
    html = render(
      partial: "shared/ui/page_header",
      locals: { title: "Vendors", actions: '<a href="/setup/vendors/new" class="ss-btn">New</a>'.html_safe }
    )

    assert_includes html, "ss-page-header"
    assert_includes html, "<h1>Vendors</h1>"
    assert_includes html, "ss-page-actions"
  end

  test "forms page_header delegates to shared ui page_header" do
    html = render(partial: "shared/forms/page_header", locals: { title: "Formats" })

    assert_includes html, "ss-page-header"
    assert_includes html, "<h1>Formats</h1>"
  end

  test "alert partial renders warning and error variants" do
    warning = render(partial: "shared/ui/alert", locals: { variant: :warning, title: "Heads up", message: "Check setup." })
    error = render(partial: "shared/ui/alert", locals: { variant: :error, message: "Blocked." })

    assert_includes warning, "ss-alert--warning"
    assert_includes warning, "ss-alert__title"
    assert_includes error, "ss-alert--error"
    assert_includes error, 'role="alert"'
  end

  test "errors partial renders alert list instead of flash markup" do
    vendor = Vendor.new
    vendor.errors.add(:name, "can't be blank")

    html = render(partial: "shared/forms/errors", locals: { record: vendor })

    assert_includes html, "ss-alert--error"
    assert_includes html, "<li>Name can&#39;t be blank</li>"
    assert_not_includes html, "flash-alert"
  end

  test "empty_state partial renders title message and actions" do
    html = render(
      partial: "shared/ui/empty_state",
      locals: {
        title: "No vendors",
        message: "Create one to get started.",
        actions: '<a href="/new" class="ss-btn">New</a>'.html_safe
      }
    )

    assert_includes html, "ss-empty-state"
    assert_includes html, "ss-empty-state__title"
    assert_includes html, "ss-empty-state__message"
    assert_includes html, "ss-empty-state__actions"
    assert_includes html, 'href="/new"'
  end

  test "reports empty_state delegates to shared ui empty_state" do
    html = render(partial: "reports/shared/empty_state", locals: { title: "No rows", message: "Widen the range." })

    assert_includes html, "ss-empty-state__title"
    assert_includes html, "ss-empty-state__message"
  end
end
