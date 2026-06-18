# frozen_string_literal: true

require "test_helper"

class Purchasing::LineLookupTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @variant.update!(sku: "9780123456789")
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "VEND-ABC",
      supplier_discount_bps: 4000,
      active: true
    )
  end

  test "exact vendor item number match" do
    result = Purchasing::LineLookup.call(
      store: @store,
      query: "VEND-ABC",
      vendor: @vendor,
      context: :order
    )

    assert_equal :found, result.status
    assert_equal @variant.id, result.matches.first.variant.id
  end

  test "delegates to variant lookup for isbn sku" do
    result = Purchasing::LineLookup.call(store: @store, query: "9780123456789", context: :order)

    assert_equal :found, result.status
    assert_equal @variant.id, result.matches.first.variant.id
  end

  test "receive context matches open purchase order line by sku" do
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      attrs: { status: "submitted", submitted_at: Time.current, submitted_by_user: @user },
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 5) ]
    )
    po_line = order.purchase_order_lines.first

    result = Purchasing::LineLookup.call(
      store: @store,
      query: @variant.sku,
      context: :receive,
      purchase_order: order,
      vendor: @vendor
    )

    assert_equal :found, result.status
    assert_equal po_line.id, result.matches.first.purchase_order_line.id
    assert_equal @variant.id, result.matches.first.variant.id
  end

  test "receive context matches open purchase order line by vendor item number" do
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      attrs: { status: "submitted", submitted_at: Time.current, submitted_by_user: @user },
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 3) ]
    )

    result = Purchasing::LineLookup.call(
      store: @store,
      query: "VEND-ABC",
      context: :receive,
      purchase_order: order,
      vendor: @vendor
    )

    assert_equal :found, result.status
    assert_equal order.purchase_order_lines.first.id, result.matches.first.purchase_order_line.id
  end
end
