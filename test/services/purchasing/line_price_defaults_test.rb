# frozen_string_literal: true

require "test_helper"

class Purchasing::LinePriceDefaultsTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @vendor = create_vendor!(default_supplier_discount_bps: 4000)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @variant.product.update!(list_price_cents: 2000)
  end

  test "resolves list price from product and cost from vendor discount" do
    defaults = Purchasing::LinePriceDefaults.resolve(variant: @variant, vendor: @vendor)

    assert_equal 2000, defaults.unit_list_price_cents
    assert_equal 4000, defaults.supplier_discount_bps
    assert_equal 1200, defaults.unit_cost_cents
  end

  test "falls back to variant selling price when product list price is zero" do
    @variant.product.update!(list_price_cents: 0)
    @variant.update!(selling_price_cents: 1500)

    defaults = Purchasing::LinePriceDefaults.resolve(variant: @variant, vendor: @vendor)

    assert_equal 1500, defaults.unit_list_price_cents
    assert_equal 900, defaults.unit_cost_cents
  end

  test "uses sourcing discount override when present" do
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      supplier_discount_bps: 5000,
      active: true
    )

    defaults = Purchasing::LinePriceDefaults.resolve(variant: @variant, vendor: @vendor)

    assert_equal 5000, defaults.supplier_discount_bps
    assert_equal 1000, defaults.unit_cost_cents
  end

  test "receipt line inherits pricing from purchase order line" do
    store = create_store!
    order = PurchaseOrder.create!(store: store, vendor: @vendor, status: "submitted")
    po_line = order.purchase_order_lines.create!(
      product_variant: @variant,
      vendor: @vendor,
      quantity_ordered: 1,
      quantity_received: 0,
      status: "open",
      unit_list_price_cents: 2500,
      supplier_discount_bps: 3000,
      unit_cost_cents: 1750
    )
    receipt = Receipt.create!(store: store, vendor: @vendor, receipt_type: "po_backed", status: "draft")
    line = receipt.receipt_lines.build(product_variant: @variant, purchase_order_line: po_line)

    Purchasing::LinePriceDefaults.apply!(line)

    assert_equal 2500, line.unit_list_price_cents
    assert_equal 3000, line.supplier_discount_bps
    assert_equal 1750, line.unit_cost_cents
  end

  test "apply fills blank purchase order line fields only" do
    store = create_store!
    order = PurchaseOrder.create!(store: store, vendor: @vendor, status: "draft")
    line = order.purchase_order_lines.build(
      product_variant: @variant,
      quantity_ordered: 1,
      unit_cost_cents: 999
    )

    Purchasing::LinePriceDefaults.apply!(line)

    assert_equal 2000, line.unit_list_price_cents
    assert_equal 4000, line.supplier_discount_bps
    assert_equal 999, line.unit_cost_cents
  end
end
