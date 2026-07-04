# frozen_string_literal: true

require "test_helper"

class VendorCapabilitiesTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @vendor = create_vendor!(
      name: "Wholesaler Test",
      availability_workflow: "order_to_confirm",
      order_submission_method: "edi_x12",
      fulfillment_methods_supported: VendorCapabilities::WHOLESALER_FULFILLMENT_METHODS
    )
  end

  test "wholesaler profile stores capability fields" do
    assert_equal "order_to_confirm", @vendor.availability_workflow
    assert_equal "edi_x12", @vendor.order_submission_method
    assert @vendor.supports_fulfillment_method?(:ship_to_store)
    assert @vendor.supports_fulfillment_method?(:vendor_direct_to_customer)
  end

  test "rejects invalid fulfillment method" do
    vendor = Vendor.new(name: "Bad Vendor", fulfillment_methods_supported: [ "invalid" ])
    assert_not vendor.valid?
  end
end
