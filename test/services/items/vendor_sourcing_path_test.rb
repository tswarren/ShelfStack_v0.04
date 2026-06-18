# frozen_string_literal: true

require "test_helper"

class Items::VendorSourcingPathTest < ActiveSupport::TestCase
  setup do
    seed_phase5_reference_data!
    @product = create_product!
    @variant = create_product_variant!(product: @product)
    @vendor = create_vendor!
  end

  test "routes to new product vendor when product has no vendors" do
    path = Items::VendorSourcingPath.for(@variant)

    assert_includes path, "/items/products/#{@product.id}/product_vendors/new"
  end

  test "routes to edit product vendor when sourcing record exists" do
    product_vendor = ProductVendor.create!(
      product: @product,
      vendor: @vendor,
      vendor_item_number: "PV-1",
      active: true,
      preferred: true
    )

    path = Items::VendorSourcingPath.for(@variant)

    assert_includes path, "/items/products/#{@product.id}/product_vendors/#{product_vendor.id}/edit"
  end

  test "routes to edit product vendor when sourcing record is missing item number" do
    product_vendor = ProductVendor.create!(
      product: @product,
      vendor: @vendor,
      vendor_item_number: nil,
      active: true,
      preferred: true
    )

    path = Items::VendorSourcingPath.for(@variant)

    assert_includes path, "/items/products/#{@product.id}/product_vendors/#{product_vendor.id}/edit"
  end
end
