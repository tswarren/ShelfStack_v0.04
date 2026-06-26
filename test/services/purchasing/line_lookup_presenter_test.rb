# frozen_string_literal: true

require "test_helper"

class Purchasing::LineLookupPresenterTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @vendor = create_vendor!(default_supplier_discount_bps: 4000)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @variant.product.update!(list_price_cents: 2000)
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "V-99",
      supplier_discount_bps: 4000,
      returnability_status: "returnable",
      active: true
    )
    @request = PurchaseRequest.create!(store: @store, status: "open")
    @request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 4,
      status: "open"
    )
  end

  test "enriches match json with purchasing context fields" do
    match = Purchasing::LineLookup::Match.new(variant: @variant, purchase_order_line: nil)
    result = Purchasing::LineLookup::Result.new(status: :found, matches: [ match ], message: nil)

    json = Purchasing::LineLookupPresenter.as_json(result, store: @store, vendor: @vendor)
    row = json[:matches].first

    assert_equal "V-99", row[:vendor_item_number]
    assert row[:sourcing_record_present]
    assert_equal "returnable", row[:returnability_status]
    assert_equal 4, row[:open_tbo_quantity]
    assert_equal 2000, row[:unit_list_price_cents]
    assert_equal 4000, row[:supplier_discount_bps]
    assert_equal 1200, row[:unit_cost_cents]
  end

  test "open tbo quantity uses remaining quantity after partial order" do
    create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [
        create_purchase_order_line_attrs(
          variant: @variant,
          vendor: @vendor,
          quantity_ordered: 1,
          purchase_request_line: @request.purchase_request_lines.first
        )
      ]
    )

    match = Purchasing::LineLookup::Match.new(variant: @variant, purchase_order_line: nil)
    result = Purchasing::LineLookup::Result.new(status: :found, matches: [ match ], message: nil)
    json = Purchasing::LineLookupPresenter.as_json(result, store: @store, vendor: @vendor)

    assert_equal 3, json[:matches].first[:open_tbo_quantity]
  end

  test "includes purchase order line fields in receive context" do
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 6) ]
    )
    po_line = order.purchase_order_lines.first
    po_line.update_columns(quantity_received: 2, status: "partially_received")

    match = Purchasing::LineLookup::Match.new(variant: @variant, purchase_order_line: po_line)
    result = Purchasing::LineLookup::Result.new(status: :found, matches: [ match ], message: nil)

    json = Purchasing::LineLookupPresenter.as_json(result, store: @store, vendor: @vendor, purchase_order: order)
    row = json[:matches].first

    assert_equal po_line.id, row[:purchase_order_line_id]
    assert_equal 4, row[:quantity_expected]
  end
end
