# frozen_string_literal: true

require "test_helper"

class Bisac::CategoryNodeImporterTest < ActiveSupport::TestCase
  FIXTURE_PATH = Rails.root.join("test/fixtures/files/bisac_sample.csv")

  test "imports flat nodes without hierarchy" do
    result = Bisac::CategoryNodeImporter.call(path: FIXTURE_PATH)

    scheme = CategoryScheme.find_by!(scheme_key: "bisac")
    assert_equal "bisac", scheme.purpose
    assert_equal 5, result.total
    assert result.created.positive?

    scheme.category_nodes.find_each do |node|
      assert_nil node.parent_id
    end

    root = scheme.category_nodes.find_by!(node_key: "fic000000")
    fantasy = scheme.category_nodes.find_by!(node_key: "fic009000")
    contemporary = scheme.category_nodes.find_by!(node_key: "fic009010")
    comics = scheme.category_nodes.find_by!(node_key: "cgn004010")

    assert_equal "Fiction / General", root.name
    assert_equal "Fiction / Fantasy / General", fantasy.name
    assert_equal "Fiction / Fantasy / Contemporary", contemporary.name
    assert_equal "Comics & Graphic Novels / Crime & Mystery", comics.name
  end

  test "import is idempotent" do
    Bisac::CategoryNodeImporter.call(path: FIXTURE_PATH)
    second = Bisac::CategoryNodeImporter.call(path: FIXTURE_PATH)

    assert_equal 0, second.created
    assert_equal 0, second.updated
    assert_equal 5, second.total
  end
end
