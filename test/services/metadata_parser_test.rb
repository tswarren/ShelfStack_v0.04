# frozen_string_literal: true

require "test_helper"

class MetadataParserTest < ActiveSupport::TestCase
  test "parse creators with roles and comma names" do
    result = MetadataParser.parse_creators("Smith, John [author]; The Beatles [performer]")
    assert_equal "Smith, John", result.first["display_name"]
    assert_equal "Smith", result.first["family_name"]
    assert_equal "John", result.first["given_names"]
    assert_equal [ "author" ], result.first["roles"]
    assert_equal "The Beatles", result.last["display_name"]
    assert_equal [ "performer" ], result.last["roles"]
  end

  test "parse subjects with scheme and code" do
    result = MetadataParser.parse_subjects("HISTORY > General [BISAC/HIS000000]; Comedy [local]")
    assert_equal "HISTORY > General", result.first["heading"]
    assert_equal "bisac", result.first["scheme"]
    assert_equal "HIS000000", result.first["code"]
    assert_equal "Comedy", result.last["heading"]
    assert_equal "local", result.last["scheme"]
    assert_nil result.last["code"]
  end

  test "parse subjects defaults scheme to local" do
    result = MetadataParser.parse_subjects("Mystery")
    assert_equal "local", result.first["scheme"]
    assert_equal "Mystery", result.first["heading"]
  end
end
