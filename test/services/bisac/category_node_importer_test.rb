# frozen_string_literal: true

require "test_helper"

class Bisac::CategoryNodeImporterTest < ActiveSupport::TestCase
  FIXTURE_PATH = Rails.root.join("test/fixtures/files/bisac_sample.csv")

  test "imports hierarchy with synthesized parent nodes" do
    result = Bisac::CategoryNodeImporter.call(path: FIXTURE_PATH)

    scheme = CategoryScheme.find_by!(scheme_key: "bisac")
    assert_equal "bisac", scheme.purpose
    assert_equal 6, result.total
    assert result.created.positive?

    root = scheme.category_nodes.find_by!(node_key: "fic000000")
    fantasy = scheme.category_nodes.find_by!(node_key: "fic009000")
    contemporary = scheme.category_nodes.find_by!(node_key: "fic009010")
    synthesized = scheme.category_nodes.find_by!(node_key: "cgn004000")

    assert_nil root.parent_id
    assert_equal root, fantasy.parent
    assert_equal fantasy, contemporary.parent
    assert_equal "Comics & Graphic Novels / General", synthesized.name
  end

  test "import is idempotent" do
    Bisac::CategoryNodeImporter.call(path: FIXTURE_PATH)
    second = Bisac::CategoryNodeImporter.call(path: FIXTURE_PATH)

    assert_equal 0, second.created
    assert_equal 0, second.updated
    assert_equal 6, second.total
  end
end
