# frozen_string_literal: true

require "test_helper"

class ReportsHelperTest < ActionView::TestCase
  include ReportsHelper
  include SetupFormatHelper

  test "format_report_money formats positive amounts" do
    assert_equal "$12.99", format_report_money(1299)
  end

  test "format_report_money includes thousands separators" do
    assert_equal "$1,234.56", format_report_money(123_456)
  end

  test "format_report_money returns em dash for nil" do
    assert_equal "—", format_report_money(nil)
  end

  test "format_report_money signed negative uses minus prefix" do
    assert_equal "- $4.50", format_report_money(-450, signed: true)
  end

  test "format_report_money signed negative includes thousands separators" do
    assert_equal "- $1,234.56", format_report_money(-123_456, signed: true)
  end

  test "format_report_basis_points delegates to basis points helper" do
    assert_equal "6.25%", format_report_basis_points(625)
  end

  test "format_report_quantity formats whole numbers" do
    assert_equal "42", format_report_quantity(42)
  end

  test "format_report_date includes basis label when provided" do
    time = Time.zone.parse("2026-06-15 14:30:00")
    Current.store = Store.new(time_zone: "America/New_York")

    assert_match "Business date", format_report_date(time, basis: "business_date")
  end

  test "report_date_basis_label humanizes known keys" do
    assert_equal "Posted at", report_date_basis_label("posted_at")
  end
end
