# frozen_string_literal: true

require "test_helper"

class ProductVendorTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @vendor = create_vendor!
    @product = create_product!
  end

  test "requires unique product and vendor pair" do
    ProductVendor.create!(product: @product, vendor: @vendor, active: true)
    duplicate = ProductVendor.new(product: @product, vendor: @vendor, active: true)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:product_id], "has already been taken"
  end

  test "validates supplier discount basis points range" do
    record = ProductVendor.new(product: @product, vendor: @vendor, supplier_discount_bps: 10_001, active: true)

    assert_not record.valid?
    assert_includes record.errors[:supplier_discount_bps], "must be less than or equal to 10000"
  end
end
