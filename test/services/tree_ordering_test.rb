# frozen_string_literal: true

require "test_helper"

class TreeOrderingTest < ActiveSupport::TestCase
  Node = Struct.new(:id, :parent_id, :name, :short_name, :sort_order, keyword_init: true)

  test "orders top parents by sort order then depth-first children below each parent" do
    records = [
      Node.new(id: 1, parent_id: nil, name: "Root B", short_name: "RB", sort_order: 20),
      Node.new(id: 2, parent_id: nil, name: "Root A", short_name: "RA", sort_order: 10),
      Node.new(id: 3, parent_id: 2, name: "Child B", short_name: "CB", sort_order: 20),
      Node.new(id: 4, parent_id: 2, name: "Child A", short_name: "CA", sort_order: 10)
    ]

    rows = TreeOrdering.rows(records)

    assert_equal [ 2, 4, 3, 1 ], rows.map { |row| row.record.id }
    assert_equal [ 0, 1, 1, 0 ], rows.map(&:depth)
  end

  test "finishes a parent subtree before the next top parent even when child sort order is lower" do
    records = [
      Node.new(id: 1, parent_id: nil, name: "Store Floor", short_name: "SF", sort_order: 0),
      Node.new(id: 2, parent_id: 1, name: "Front Table", short_name: "FT", sort_order: 10),
      Node.new(id: 3, parent_id: 2, name: "Staff Picks", short_name: "SP", sort_order: 15),
      Node.new(id: 4, parent_id: 1, name: "Front Window", short_name: "FW", sort_order: 15),
      Node.new(id: 5, parent_id: nil, name: "Media Wall", short_name: "MW", sort_order: 20)
    ]

    rows = TreeOrdering.rows(records)

    assert_equal [ 1, 2, 3, 4, 5 ], rows.map { |row| row.record.id }
  end

  test "sorts siblings by sort order only within the same parent" do
    records = [
      Node.new(id: 1, parent_id: nil, name: "Root", short_name: "R", sort_order: 0),
      Node.new(id: 2, parent_id: 1, name: "Later Child", short_name: "LC", sort_order: 40),
      Node.new(id: 3, parent_id: 1, name: "Earlier Child", short_name: "EC", sort_order: 10)
    ]

    rows = TreeOrdering.rows(records)

    assert_equal [ 1, 3, 2 ], rows.map { |row| row.record.id }
  end

  test "treats missing parent as orphan root after valid top parents" do
    records = [
      Node.new(id: 1, parent_id: nil, name: "Root", short_name: "R", sort_order: 0),
      Node.new(id: 2, parent_id: 99, name: "Orphan", short_name: "O", sort_order: 5)
    ]

    rows = TreeOrdering.rows(records)

    assert_equal [ 1, 2 ], rows.map { |row| row.record.id }
    assert_equal [ 0, 0 ], rows.map(&:depth)
  end
end
