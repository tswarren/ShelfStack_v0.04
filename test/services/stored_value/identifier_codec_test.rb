# frozen_string_literal: true

require "test_helper"

class StoredValue::IdentifierCodecTest < ActiveSupport::TestCase
  test "generate produces valid check digit identifier" do
    generated = StoredValue::IdentifierCodec.generate
    assert generated[:lookup_digest].present?
    assert generated[:display_value_masked].start_with?("****")
  end

  test "normalize strips separators" do
    assert_equal "1234567890123456", StoredValue::IdentifierCodec.normalize("1234-5678-9012-3456")
  end
end
