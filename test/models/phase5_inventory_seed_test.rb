# frozen_string_literal: true

require "test_helper"

class Phase5InventorySeedTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    Seeds::Phase3CatalogProducts.seed!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "phase5 inventory seed is idempotent" do
    vendor = Vendor.find_by!(name: "Ingram")

    Seeds::Phase5Inventory.seed!
    count_after_first = ProductVendor.where(vendor: vendor, product: @variant.product).count

    Seeds::Phase5Inventory.seed!
    count_after_second = ProductVendor.where(vendor: vendor, product: @variant.product).count

    assert_equal 1, count_after_first
    assert_equal count_after_first, count_after_second
  end
end
