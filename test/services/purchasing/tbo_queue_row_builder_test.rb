# frozen_string_literal: true

require "test_helper"

class Purchasing::TboQueueRowBuilderTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    InventoryBalance.create!(store: @store, product_variant: @variant, quantity_on_hand: 7)

    @request = PurchaseRequest.create!(store: @store, status: "open")
    @line = @request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 10,
      status: "open"
    )

    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "V-1",
      active: true
    )
  end

  test "includes inventory context and remaining quantity" do
    rows = Purchasing::TboQueueRowBuilder.call(store: @store, vendor: @vendor)

    assert_equal 1, rows.size
    row = rows.first
    assert_equal 7, row.quantity_on_hand
    assert_equal 10, row.remaining_quantity
    assert_equal 10, row.open_tbo_quantity
    assert row.sourcing.sourcing_record_present
  end

  test "open tbo quantity reflects remaining quantity after partial order" do
    create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [
        create_purchase_order_line_attrs(
          variant: @variant,
          vendor: @vendor,
          quantity_ordered: 4,
          purchase_request_line: @line
        )
      ]
    )

    rows = Purchasing::TboQueueRowBuilder.call(store: @store, vendor: @vendor)

    assert_equal 1, rows.size
    assert_equal 6, rows.first.remaining_quantity
    assert_equal 6, rows.first.open_tbo_quantity
  end

  test "excludes lines with no remaining quantity" do
    order = Purchasing::BuildPurchaseOrder.call(
      store: @store,
      vendor: @vendor,
      created_by_user: create_user!,
      purchase_request_lines: [ @line ]
    )
    assert_equal 1, order.purchase_order_lines.count

    rows = Purchasing::TboQueueRowBuilder.call(store: @store, vendor: @vendor)

    assert_empty rows
  end

  test "filters by department" do
    other_department = create_department!
    other_sub = create_sub_department!(department: other_department)
    other_variant = create_product_variant!(sub_department: other_sub, inventory_behavior: "standard_physical")
    @request.purchase_request_lines.create!(
      product_variant: other_variant,
      requested_quantity: 2,
      status: "open"
    )

    rows = Purchasing::TboQueueRowBuilder.call(
      store: @store,
      vendor: @vendor,
      department_id: @variant.sub_department.department_id
    )

    assert_equal 1, rows.size
    assert_equal @line.id, rows.first.line.id
  end

  test "filters by product format" do
    hardcover = Format.find_by(format_key: "hardcover") || Format.active_records.first
    paperback = Format.active_records.where.not(id: hardcover.id).first ||
      Format.create!(format_key: "pb_tbo", name: "Paperback TBO", active: true)

    @variant.product.update!(format: hardcover)
    other_variant = create_product_variant!(inventory_behavior: "standard_physical")
    other_variant.product.update!(format: paperback)
    @request.purchase_request_lines.create!(
      product_variant: other_variant,
      requested_quantity: 2,
      status: "open"
    )

    rows = Purchasing::TboQueueRowBuilder.call(
      store: @store,
      vendor: @vendor,
      format_id: hardcover.id
    )

    assert_equal 1, rows.size
    assert_equal @line.id, rows.first.line.id
  end
end
