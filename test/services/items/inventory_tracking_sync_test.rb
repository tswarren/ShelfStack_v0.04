# frozen_string_literal: true

require "test_helper"

class Items::InventoryTrackingSyncTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @product = create_product!(product_type: "physical")
    @variant = create_product_variant!(product: @product, inventory_behavior: "standard_physical")
  end

  test "inventory selection sets override and standard_physical behavior" do
    Items::InventoryTrackingSync.apply_tracking_selection!(variant: @variant, tracking: "inventory")

    assert_equal "inventory", @variant.inventory_tracking_override
    assert_equal "standard_physical", @variant.inventory_behavior
  end

  test "non-inventory on physical product uses non_inventory behavior not standard_physical" do
    Items::InventoryTrackingSync.apply_tracking_selection!(variant: @variant, tracking: "non_inventory")

    assert_equal "non_inventory", @variant.inventory_tracking_override
    assert_equal "non_inventory", @variant.inventory_behavior
  end

  test "non-inventory on digital product uses digital_asset behavior" do
    @product.update!(product_type: "digital")
    @variant.update!(inventory_behavior: "standard_physical")

    Items::InventoryTrackingSync.apply_tracking_selection!(variant: @variant, tracking: "non_inventory")

    assert_equal "digital_asset", @variant.inventory_behavior
  end

  test "legacy behavior edit clears override" do
    @variant.update!(inventory_tracking_override: "inventory", inventory_behavior: "standard_physical")

    Items::InventoryTrackingSync.apply_legacy_behavior_edit!(variant: @variant, inventory_behavior: "digital_asset")

    assert_nil @variant.inventory_tracking_override
    assert_equal "digital_asset", @variant.inventory_behavior
  end

  test "legacy behavior preview reports tracking and eligibility change" do
    preview = Items::InventoryTrackingSync.preview_legacy_behavior_edit(
      variant: @variant,
      inventory_behavior: "non_inventory"
    )

    assert_equal "inventory", preview.previous_tracking
    assert_equal "non_inventory", preview.new_tracking
    assert preview.previous_eligible
    assert_not preview.new_eligible
  end

  test "seed_defaults_from_product uses product type when default tracking blank" do
    @product.update!(product_type: "digital", default_inventory_tracking: nil)
    @variant.inventory_behavior = "standard_physical"

    Items::InventoryTrackingSync.seed_defaults_from_product!(variant: @variant)

    assert_equal "digital_asset", @variant.inventory_behavior
  end

  test "seed_defaults_from_product prefers product default inventory tracking" do
    @product.update!(product_type: "physical", default_inventory_tracking: "non_inventory")
    @variant.inventory_behavior = "standard_physical"

    Items::InventoryTrackingSync.seed_defaults_from_product!(variant: @variant)

    assert_equal "non_inventory", @variant.inventory_behavior
  end
end
