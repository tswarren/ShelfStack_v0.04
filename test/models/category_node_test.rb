# frozen_string_literal: true

require "test_helper"

class CategoryNodeTest < ActiveSupport::TestCase
  test "descendant_ids_including_self returns node and all descendants" do
    scheme = CategoryScheme.create!(
      scheme_key: "tree_test",
      name: "Tree Test Scheme",
      purpose: "internal",
      active: true
    )
    root = CategoryNode.create!(category_scheme: scheme, node_key: "root", name: "Root", sort_order: 1, active: true)
    child = CategoryNode.create!(
      category_scheme: scheme,
      parent: root,
      node_key: "child",
      name: "Child",
      sort_order: 1,
      active: true
    )
    grandchild = CategoryNode.create!(
      category_scheme: scheme,
      parent: child,
      node_key: "grandchild",
      name: "Grandchild",
      sort_order: 1,
      active: true
    )
    other = CategoryNode.create!(category_scheme: scheme, node_key: "other", name: "Other", sort_order: 2, active: true)

    assert_equal [ root.id, child.id, grandchild.id ].sort,
                 CategoryNode.descendant_ids_including_self(root).sort
    assert_equal [ child.id, grandchild.id ].sort,
                 CategoryNode.descendant_ids_including_self(child).sort
    assert_equal [ grandchild.id ],
                 CategoryNode.descendant_ids_including_self(grandchild)
    assert_not_includes CategoryNode.descendant_ids_including_self(root), other.id
  end
end
