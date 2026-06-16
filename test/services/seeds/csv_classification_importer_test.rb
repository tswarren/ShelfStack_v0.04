# frozen_string_literal: true

require "test_helper"
require Rails.root.join("db/seeds/concerns/csv_classification_importer")

class CsvClassificationImporterTest < ActiveSupport::TestCase
  FIXTURE_DIR = Rails.root.join("test/fixtures/files/seeds").freeze

  setup do
    create_store!(store_number: "001")
    Seeds::CsvClassificationImporter.import_tax_categories!(path: FIXTURE_DIR.join("tax_categories.csv"))
    Seeds::CsvClassificationImporter.import_departments!(path: FIXTURE_DIR.join("departments.csv"))
    Seeds::CsvClassificationImporter.import_sub_departments!(path: FIXTURE_DIR.join("sub_departments.csv"))
  end

  test "imports display location hierarchy from csv" do
    locations = Seeds::CsvClassificationImporter.import_display_locations!(path: FIXTURE_DIR.join("display_locations.csv"))

    assert locations.key?("books")
    assert_equal "salesfloor", locations.fetch("books").parent.short_name
  end

  test "imports store categories with default foreign keys" do
    Seeds::CsvClassificationImporter.import_display_locations!(path: FIXTURE_DIR.join("display_locations.csv"))
    scheme = create_category_scheme!(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY, name: "Store Categories CSV")

    nodes = Seeds::CsvClassificationImporter.import_store_category_nodes!(
      scheme: scheme,
      path: FIXTURE_DIR.join("store_categories.csv")
    )

    fiction = nodes.fetch("fiction")
    assert_equal "Fiction", fiction.name
    assert_equal SubDepartment.find_by!(sub_department_key: "general_trade").id, fiction.default_sub_department_id
    assert_equal DisplayLocation.find_by!(short_name: "books").id, fiction.default_display_location_id
    assert_equal "books", fiction.parent.node_key
  end

  test "allows duplicate subdepartment short names" do
    assert_equal 2, SubDepartment.where(short_name: "Games").count
  end
end
