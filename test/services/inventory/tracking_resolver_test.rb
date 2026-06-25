# frozen_string_literal: true

require "test_helper"

class Inventory::TrackingResolverTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @variant = create_product_variant!
  end

  test "maps standard_physical variant to inventory" do
    @variant.update!(inventory_behavior: "standard_physical")

    assert_equal "inventory", Inventory::TrackingResolver.resolve(@variant)
    assert Inventory::TrackingResolver.inventory?(@variant)
  end

  ProductVariant::INVENTORY_BEHAVIORS.without("standard_physical").each do |behavior|
    test "maps #{behavior} variant to non_inventory" do
      @variant.update!(inventory_behavior: behavior)

      assert_equal "non_inventory", Inventory::TrackingResolver.resolve(@variant)
      assert_not Inventory::TrackingResolver.inventory?(@variant)
    end
  end

  test "maps legacy behavior strings" do
    assert Inventory::TrackingResolver.inventory?("standard_physical")
    assert_not Inventory::TrackingResolver.inventory?("digital_asset")
    assert_not Inventory::TrackingResolver.inventory?("non_inventory")
  end

  test "maps tracking strings directly" do
    assert_equal "inventory", Inventory::TrackingResolver.resolve("inventory")
    assert_equal "non_inventory", Inventory::TrackingResolver.resolve("non_inventory")
  end

  test "inventory? fails closed for nil" do
    assert_equal "non_inventory", Inventory::TrackingResolver.resolve(nil)
    assert_not Inventory::TrackingResolver.inventory?(nil)
  end

  test "resolve! raises for nil" do
    assert_raises(Inventory::TrackingResolver::UnknownTrackingValueError) do
      Inventory::TrackingResolver.resolve!(nil)
    end
  end

  test "inventory? fails closed for unknown strings" do
    assert_equal "non_inventory", Inventory::TrackingResolver.resolve("totally_unknown")
    assert_not Inventory::TrackingResolver.inventory?("totally_unknown")
  end

  test "resolve! raises for unknown strings" do
    assert_raises(Inventory::TrackingResolver::UnknownTrackingValueError) do
      Inventory::TrackingResolver.resolve!("totally_unknown")
    end
  end

  test "tracking_for_behavior maps standard_physical only" do
    assert_equal "inventory", Inventory::TrackingResolver.tracking_for_behavior("standard_physical")
    assert_equal "non_inventory", Inventory::TrackingResolver.tracking_for_behavior("drop_ship")
  end

  test "variant override takes precedence over behavior" do
    @variant.update!(inventory_tracking_override: "non_inventory", inventory_behavior: "standard_physical")

    assert_equal "non_inventory", Inventory::TrackingResolver.resolve(@variant)
  end

  test "product default applies when behavior absent" do
    temp = @variant.dup
    temp.inventory_behavior = nil
    temp.inventory_tracking_override = nil
    temp.product.default_inventory_tracking = "non_inventory"

    assert_equal "non_inventory", Inventory::TrackingResolver.resolve(temp)
  end

  test "product_type default applies when override behavior and product default absent" do
    temp = @variant.dup
    temp.inventory_behavior = nil
    temp.inventory_tracking_override = nil
    temp.product.default_inventory_tracking = nil
    temp.product.product_type = "digital"

    assert_equal "non_inventory", Inventory::TrackingResolver.resolve(temp)
  end

  test "changing product default does not affect variant with populated behavior" do
    @variant.update!(inventory_behavior: "standard_physical", inventory_tracking_override: nil)
    @variant.product.update!(default_inventory_tracking: "non_inventory")

    assert_equal "inventory", Inventory::TrackingResolver.resolve(@variant)
  end

  test "resolution chain override behavior product default product_type" do
    product = @variant.product
    product.update!(default_inventory_tracking: "non_inventory", product_type: "physical")

    @variant.update!(inventory_behavior: "digital_asset", inventory_tracking_override: nil)
    assert_equal "non_inventory", Inventory::TrackingResolver.resolve(@variant)

    @variant.update!(inventory_tracking_override: "inventory")
    assert_equal "inventory", Inventory::TrackingResolver.resolve(@variant)
  end
end
