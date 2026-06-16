# frozen_string_literal: true

require "test_helper"

class CategorizationTest < ActiveSupport::TestCase
  test "allows only one primary categorization per scheme" do
    scheme = create_category_scheme!
    node_one = create_category_node!(category_scheme: scheme, node_key: "fiction", name: "Fiction")
    node_two = create_category_node!(category_scheme: scheme, node_key: "biography", name: "Biography")
    variant = create_product_variant!

    variant.categorizations.create!(category_node: node_one, primary: true, source: "manual")

    duplicate = variant.categorizations.build(category_node: node_two, primary: true, source: "manual")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:primary], "already assigned for this scheme"
  end
end
