# frozen_string_literal: true

require "test_helper"

class SourcingSuggestVendorsTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase5TestHelper

  setup do
    seed_phase3_reference_data!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: nil,
      active: true,
      preferred: true
    )
  end

  test "does not warn when vendor item number is missing but primary identifier exists" do
    candidates = Sourcing::SuggestVendors.call!(variant: @variant)

    assert_equal 1, candidates.size
    assert_empty candidates.first.warnings
  end
end
