# frozen_string_literal: true

require "test_helper"

class IngramCatalogImport::FormatMapperTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
  end

  test "maps hardcover and paperback" do
    assert_equal "hardcover", IngramCatalogImport::FormatMapper.resolve!("Hardcover").format_key
    assert_equal "trade_paperback", IngramCatalogImport::FormatMapper.resolve!("Paperback").format_key
  end

  test "raises for unknown format" do
    error = assert_raises(IngramCatalogImport::FormatMapper::FormatError) do
      IngramCatalogImport::FormatMapper.resolve!("Unknown Binding")
    end

    assert_includes error.message, "Unmapped"
  end
end
