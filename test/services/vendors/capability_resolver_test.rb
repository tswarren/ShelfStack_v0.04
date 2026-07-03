# frozen_string_literal: true

require "test_helper"

class VendorsCapabilityResolverTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @vendor = create_vendor!(
      availability_workflow: "order_to_confirm",
      order_submission_method: "edi_x12",
      fulfillment_methods_supported: [ "ship_to_store" ]
    )
  end

  test "returns vendor defaults" do
    result = Vendors::CapabilityResolver.call(vendor: @vendor)

    assert_equal "order_to_confirm", result.availability_workflow
    assert_equal "vendor", result.capability_source
    assert_includes result.fulfillment_methods_supported, "ship_to_store"
  end
end
