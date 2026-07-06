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
end
