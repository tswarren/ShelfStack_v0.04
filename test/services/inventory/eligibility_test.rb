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

  test "non_inventory variant is not eligible" do
    @variant.update!(inventory_behavior: "non_inventory")
    assert_not Inventory::Eligibility.eligible?(@variant)
    assert_raises(Inventory::Eligibility::IneligibleVariantError) do
      Inventory::Eligibility.ensure_eligible!(@variant)
    end
  end
end
