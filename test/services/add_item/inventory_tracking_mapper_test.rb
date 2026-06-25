# frozen_string_literal: true

require "test_helper"

class AddItem::InventoryTrackingMapperTest < ActiveSupport::TestCase
  test "maps product types to tracking defaults" do
    assert_equal "inventory", AddItem::InventoryTrackingMapper.for_product_type("physical")
    assert_equal "non_inventory", AddItem::InventoryTrackingMapper.for_product_type("digital")
    assert_equal "non_inventory", AddItem::InventoryTrackingMapper.for_product_type("service")
    assert_equal "non_inventory", AddItem::InventoryTrackingMapper.for_product_type("financial")
    assert_equal "non_inventory", AddItem::InventoryTrackingMapper.for_product_type("non_inventory")
  end
end
