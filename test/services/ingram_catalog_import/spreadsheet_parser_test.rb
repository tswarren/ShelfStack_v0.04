# frozen_string_literal: true

require "test_helper"

class IngramCatalogImport::SpreadsheetParserTest < ActiveSupport::TestCase
  setup do
    @fixture_path = Rails.root.join("test/fixtures/files/ingram_list_sample.xls")
  end

  test "parses sample file headers and rows" do
    rows = IngramCatalogImport::SpreadsheetParser.call(path: @fixture_path)

    assert rows.size.positive?
    first = rows.first
    assert_equal "0063575019", first.product_code
    assert_equal "9780063575011", first.ean
    assert_equal "Communion: Finding My Way Back to Faith", first.product_name
    assert_equal "Hardcover", first.format
    assert_equal 3500, first.us_srp_cents
    assert_equal Date.new(2026, 6, 16), first.pub_date
  end

  test "parses paperback row pricing" do
    rows = IngramCatalogImport::SpreadsheetParser.call(path: @fixture_path)
    paperback = rows.find { |row| row.ean == "9781990105616" }

    assert_not_nil paperback
    assert_equal 1899, paperback.us_srp_cents
    assert_equal "Paperback", paperback.format
  end
end
