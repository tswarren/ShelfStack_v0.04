# frozen_string_literal: true

require "test_helper"

class Purchasing::BuildableTboLinesQueryTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @vendor = create_vendor!
    @other_vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @other_variant = create_product_variant!(
      sub_department: @variant.sub_department,
      inventory_behavior: "standard_physical"
    )

    @request_one = PurchaseRequest.create!(store: @store, status: "open")
    @line_one = @request_one.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 2,
      status: "open"
    )

    @request_two = PurchaseRequest.create!(store: @store, status: "open")
    @line_two = @request_two.purchase_request_lines.create!(
      product_variant: @other_variant,
      requested_quantity: 3,
      status: "ready_to_order"
    )

    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "V-1",
      active: true
    )
  end

  test "returns buildable lines across purchase requests for store" do
    rows = Purchasing::BuildableTboLinesQuery.call(store: @store, vendor: @vendor)

    assert_equal 2, rows.size
    assert_equal [ @line_one.id, @line_two.id ].sort, rows.map { |row| row.line.id }.sort
  end

  test "filters to sourced lines when sourced_only is true" do
    rows = Purchasing::BuildableTboLinesQuery.call(store: @store, vendor: @vendor, sourced_only: true)

    assert_equal 1, rows.size
    assert_equal @line_one.id, rows.first.line.id
    assert rows.first.sourcing.sourcing_record_present
  end

  test "excludes added_to_po and cancelled request lines" do
    @line_one.update!(status: "added_to_po")
    cancelled_request = PurchaseRequest.create!(store: @store, status: "cancelled")
    cancelled_request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 1,
      status: "open"
    )

    rows = Purchasing::BuildableTboLinesQuery.call(store: @store, vendor: @vendor)

    assert_equal 1, rows.size
    assert_equal @line_two.id, rows.first.line.id
  end
end
