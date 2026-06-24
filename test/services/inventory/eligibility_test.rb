# frozen_string_literal: true

require "test_helper"

class Inventory::EligibilityTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @variant = create_product_variant!
  end

  test "standard_physical variant is eligible" do
    @variant.update!(inventory_behavior: "standard_physical")
    assert Inventory::Eligibility.eligible?(@variant)
  end

  ProductVariant::INVENTORY_BEHAVIORS.without("standard_physical").each do |behavior|
    test "#{behavior} variant is not eligible" do
      @variant.update!(inventory_behavior: behavior)
      assert_not Inventory::Eligibility.eligible?(@variant)
    end
  end

  test "ensure_eligible! raises with tracking and legacy behavior in message" do
    @variant.update!(inventory_behavior: "non_inventory")
    error = assert_raises(Inventory::Eligibility::IneligibleVariantError) do
      Inventory::Eligibility.ensure_eligible!(@variant)
    end

    assert_includes error.message, "tracking: non_inventory"
    assert_includes error.message, "inventory_behavior: non_inventory"
  end

  test "eligible_for_pos_line? trusts snapshot before variant" do
    @variant.update!(inventory_behavior: "non_inventory")
    line = PosTransactionLine.new(
      product_variant: @variant,
      inventory_behavior_snapshot: "standard_physical"
    )

    assert Inventory::Eligibility.eligible_for_pos_line?(line)
  end

  test "eligible_for_pos_line? falls back to variant when snapshot blank" do
    @variant.update!(inventory_behavior: "standard_physical")
    line = PosTransactionLine.new(product_variant: @variant, inventory_behavior_snapshot: nil)

    assert Inventory::Eligibility.eligible_for_pos_line?(line)
  end

  test "eligible_for_pos_line? trusts inventory_tracking_snapshot first" do
    @variant.update!(inventory_behavior: "non_inventory")
    line = PosTransactionLine.new(
      product_variant: @variant,
      inventory_tracking_snapshot: "inventory"
    )

    assert Inventory::Eligibility.eligible_for_pos_line?(line)
  end

  test "eligible_for_pos_line? rejects non_inventory tracking snapshot" do
    @variant.update!(inventory_behavior: "standard_physical")
    line = PosTransactionLine.new(
      product_variant: @variant,
      inventory_tracking_snapshot: "non_inventory"
    )

    assert_not Inventory::Eligibility.eligible_for_pos_line?(line)
  end
end
