# frozen_string_literal: true

require "test_helper"

class ItemsItemPresenterBisacTest < ActiveSupport::TestCase
  test "subject headings prefer linked bisac categorizations" do
    seed_bisac_scheme!
    item = create_catalog_item!(bisac_subjects: "Legacy Subject [local]")
    node = CategoryNode.find_by!(node_key: "fic000000")
    item.categorizations.create!(category_node: node, primary: true, source: "bisac")
    presenter = Items::ItemPresenter.from_catalog_item(item)

    assert_equal [ "Fiction / General" ], presenter.subject_headings
  end
end
