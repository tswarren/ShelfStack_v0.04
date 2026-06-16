# frozen_string_literal: true

require "test_helper"

class InventoryAdjustmentTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "draft adjustment can be created" do
    adjustment = create_inventory_adjustment!(store: @store)
    assert_equal "draft", adjustment.status
    assert_includes InventoryAdjustment::ADJUSTMENT_TYPES, adjustment.adjustment_type
  end

  test "invalid adjustment type fails" do
    adjustment = InventoryAdjustment.new(store: @store, adjustment_type: "invalid", status: "draft")
    assert_not adjustment.valid?
  end

  test "cancelled draft cannot be posted via post adjustment" do
    adjustment = create_inventory_adjustment!(
      store: @store,
      attrs: { status: "cancelled" },
      lines: [ { product_variant: @variant, quantity_delta: 1, line_number: 1 } ]
    )

    assert_raises(Inventory::PostAdjustment::PostingError) do
      Inventory::PostAdjustment.call(adjustment: adjustment, posted_by_user: create_user!)
    end
  end

  test "posted adjustment cannot return to draft" do
    user = create_user!
    adjustment = create_inventory_adjustment!(
      store: @store,
      lines: [ { product_variant: @variant, quantity_delta: 1, line_number: 1 } ]
    )
    Inventory::PostAdjustment.call(adjustment: adjustment, posted_by_user: user)

    adjustment.status = "draft"
    assert_not adjustment.valid?(:update)
  end

  test "nested lines receive unique line numbers on create" do
    variant_two = create_product_variant!(
      sub_department: @variant.sub_department,
      inventory_behavior: "standard_physical"
    )

    adjustment = InventoryAdjustment.new(
      store: @store,
      adjustment_type: "manual_adjustment",
      status: "draft",
      inventory_adjustment_lines_attributes: {
        "0" => { product_variant_id: @variant.id, quantity_delta: 2 },
        "1" => { product_variant_id: variant_two.id, quantity_delta: 3 }
      }
    )

    assert adjustment.save
    assert_equal [ 1, 2 ], adjustment.inventory_adjustment_lines.order(:line_number).pluck(:line_number)
  end
end
