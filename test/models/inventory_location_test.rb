# frozen_string_literal: true

require "test_helper"

class InventoryLocationTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @other_store = create_store!(store_number: "002", name: "Store Two")
  end

  test "location saves per store" do
    location = InventoryLocation.create!(store: @store, name: "Sales Floor", short_name: "SF", sort_order: 1)
    assert location.persisted?
  end

  test "short name is unique per store" do
    InventoryLocation.create!(store: @store, name: "Sales Floor", short_name: "SF", sort_order: 1)
    duplicate = InventoryLocation.new(store: @store, name: "Another", short_name: "SF", sort_order: 2)
    assert_not duplicate.valid?
  end

  test "same short name may exist on different stores" do
    InventoryLocation.create!(store: @store, name: "Sales Floor", short_name: "SF", sort_order: 1)
    other = InventoryLocation.new(store: @other_store, name: "Sales Floor", short_name: "SF", sort_order: 1)
    assert other.valid?
  end
end
