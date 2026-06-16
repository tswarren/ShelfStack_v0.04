# frozen_string_literal: true

require "test_helper"

class InventoryAdjustmentLineTest < ActiveSupport::TestCase
  setup do
    seed_phase4_reference_data!
    @store = create_store!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @adjustment = create_inventory_adjustment!(store: @store)
    @inactive_reason = InventoryReasonCode.find_by!(reason_key: "damage").tap { |c| c.update!(active: false) }
    @inactive_location = InventoryLocation.create!(store: @store, name: "Old Room", short_name: "OLD", active: false)
  end

  test "inactive reason code cannot be assigned" do
    line = @adjustment.inventory_adjustment_lines.build(
      product_variant: @variant,
      quantity_delta: 1,
      inventory_reason_code: @inactive_reason
    )
    assert_not line.valid?
  end

  test "inactive location cannot be assigned" do
    line = @adjustment.inventory_adjustment_lines.build(
      product_variant: @variant,
      quantity_delta: 1,
      inventory_location: @inactive_location
    )
    assert_not line.valid?
  end

  test "assigns line number on create" do
    line = @adjustment.inventory_adjustment_lines.create!(product_variant: @variant, quantity_delta: 2)
    assert_equal 1, line.line_number
  end
end
