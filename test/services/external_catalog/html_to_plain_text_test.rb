# frozen_string_literal: true

require "test_helper"

class ExternalCatalogHtmlToPlainTextTest < ActiveSupport::TestCase
  test "strips tags and preserves paragraph breaks" do
    html = "<b>Intro</b><br><br><p>First paragraph.</p><ul><li>One</li><li>Two</li></ul>"

    text = ExternalCatalog::HtmlToPlainText.call(html)

    assert_includes text, "Intro"
    assert_includes text, "First paragraph."
    assert_includes text, "One"
    assert_includes text, "Two"
    assert_not_includes text, "<b>"
    assert_not_includes text, "<li>"
  end

  test "returns nil for blank input" do
    assert_nil ExternalCatalog::HtmlToPlainText.call("")
    assert_nil ExternalCatalog::HtmlToPlainText.call(nil)
  end
end
