# frozen_string_literal: true

require "test_helper"

class AddItemInventoryBehaviorMapperTest < ActiveSupport::TestCase
  test "maps product types to inventory behaviors" do
    assert_equal "standard_physical", AddItem::InventoryBehaviorMapper.for_product_type("physical")
    assert_equal "digital_asset", AddItem::InventoryBehaviorMapper.for_product_type("digital")
    assert_equal "capacitated_service", AddItem::InventoryBehaviorMapper.for_product_type("service")
    assert_equal "pure_financial", AddItem::InventoryBehaviorMapper.for_product_type("financial")
    assert_equal "non_inventory", AddItem::InventoryBehaviorMapper.for_product_type("non_inventory")
  end
end
