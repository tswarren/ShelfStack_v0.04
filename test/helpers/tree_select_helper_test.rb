# frozen_string_literal: true

require "test_helper"

class TreeSelectHelperTest < ActionView::TestCase
  include TreeSelectHelper

  Node = Struct.new(:id, :parent_id, :name, :short_name, :sort_order, keyword_init: true)

  test "builds indented options in tree order" do
    records = [
      Node.new(id: 1, parent_id: nil, name: "Store Floor", short_name: "SF", sort_order: 0),
      Node.new(id: 2, parent_id: 1, name: "Fiction", short_name: "Fiction", sort_order: 30),
      Node.new(id: 3, parent_id: nil, name: "Media Wall", short_name: "MW", sort_order: 20)
    ]

    options = tree_select_options(records)

    assert_equal 3, options.length
    assert_equal "Store Floor", options[0].first
    assert_equal 1, options[0].last
    assert_equal "#{TreeSelectHelper::TREE_SELECT_INDENT}Fiction", options[1].first
    assert_equal 2, options[1].last
    assert_equal "Media Wall", options[2].first
    assert_equal 3, options[2].last
  end
end
