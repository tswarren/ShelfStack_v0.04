# frozen_string_literal: true

require "test_helper"
require Rails.root.join("db/seeds/concerns/tsv_tree_importer")

class TsvTreeImporterTest < ActiveSupport::TestCase
  setup do
    create_department!(department_number: "001", name: "Books Dept", short_name: "Books D")
    create_tax_category!(name: "Books Tax TSV", short_name: "Books TSV")
    @sub_department = create_sub_department!(
      sub_department_key: "general_trade_books",
      name: "Trade Books TSV",
      short_name: "Trade TSV"
    )
    create_store!
  end

  test "imports display location hierarchy from tsv" do
    locations = Seeds::TsvTreeImporter.import_display_locations!(
      path: Rails.root.join("db/seeds/data/display_locations.tsv")
    )

    assert locations.key?("Front Table")
    assert_equal "Store Floor", locations.fetch("Front Table").parent.short_name
    assert_operator DisplayLocation.count, :>=, 30
  end

  test "imports store categories with default foreign keys" do
    Seeds::TsvTreeImporter.import_display_locations!(
      path: Rails.root.join("db/seeds/data/display_locations.tsv")
    )
    scheme = create_category_scheme!(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY, name: "Store Categories TSV")

    nodes = Seeds::TsvTreeImporter.import_store_category_nodes!(
      scheme: scheme,
      path: Rails.root.join("db/seeds/data/store_categories.tsv")
    )

    fiction = nodes.fetch("fiction")
    assert_equal "Fiction", fiction.name
    assert_equal @sub_department.id, fiction.default_sub_department_id
    assert_equal DisplayLocation.find_by!(short_name: "Fiction Wall").id, fiction.default_display_location_id
    assert_equal "history", nodes.fetch("military_history").parent.node_key
    assert_operator scheme.category_nodes.count, :>=, 65
  end
end
