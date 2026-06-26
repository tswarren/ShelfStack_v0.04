# frozen_string_literal: true

require "test_helper"

class OrdersPurchaseOrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "items.catalog_items.view", store: @store)
    login_user!(@user, workstation: @workstation)

    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @sub_department = @variant.sub_department
    @purchase_order = PurchaseOrder.create!(store: @store, vendor: @vendor, status: "draft")
    @line_to_keep = @purchase_order.purchase_order_lines.create!(
      product_variant: @variant,
      vendor: @vendor,
      quantity_ordered: 2,
      quantity_received: 0,
      status: "open"
    )
    @line_to_remove = @purchase_order.purchase_order_lines.create!(
      product_variant: @variant,
      vendor: @vendor,
      quantity_ordered: 1,
      quantity_received: 0,
      status: "open"
    )
  end

  test "update removes marked purchase order lines" do
    patch orders_purchase_order_path(@purchase_order), params: {
      purchase_order: {
        vendor_id: @vendor.id,
        purchase_order_lines_attributes: {
          "0" => {
            id: @line_to_keep.id,
            product_variant_id: @variant.id,
            quantity_ordered: 2,
            _destroy: "0"
          },
          "1" => {
            id: @line_to_remove.id,
            product_variant_id: @variant.id,
            quantity_ordered: 1,
            _destroy: "1"
          }
        }
      }
    }

    assert_redirected_to orders_purchase_order_path(@purchase_order)
    assert_equal 1, @purchase_order.reload.purchase_order_lines.count
    assert_equal @line_to_keep.id, @purchase_order.purchase_order_lines.first.id
  end

  test "update renumbers remaining lines after removing first line" do
    third_variant = create_product_variant!(sub_department: @sub_department, inventory_behavior: "standard_physical")
    third_line = @purchase_order.purchase_order_lines.create!(
      product_variant: third_variant,
      vendor: @vendor,
      quantity_ordered: 3,
      quantity_received: 0,
      status: "open"
    )

    patch orders_purchase_order_path(@purchase_order), params: {
      purchase_order: {
        vendor_id: @vendor.id,
        purchase_order_lines_attributes: {
          "0" => {
            id: @line_to_keep.id,
            product_variant_id: @variant.id,
            quantity_ordered: 2,
            _destroy: "1"
          },
          "1" => {
            id: @line_to_remove.id,
            product_variant_id: @variant.id,
            quantity_ordered: 1,
            _destroy: "0"
          },
          "2" => {
            id: third_line.id,
            product_variant_id: third_variant.id,
            quantity_ordered: 3,
            _destroy: "0"
          }
        }
      }
    }

    assert_redirected_to orders_purchase_order_path(@purchase_order)
    @purchase_order.reload
    assert_equal 2, @purchase_order.purchase_order_lines.count
    assert_equal [ 1, 2 ], @purchase_order.purchase_order_lines.order(:line_number).pluck(:line_number)
    assert_equal @line_to_remove.id, @purchase_order.purchase_order_lines.first.id
  end

  test "update preserves manual unit cost override" do
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "VEND-1",
      supplier_discount_bps: 4000,
      returnability_status: "returnable",
      active: true
    )
    @variant.product.update!(list_price_cents: 2000)

    patch orders_purchase_order_path(@purchase_order), params: {
      purchase_order: {
        vendor_id: @vendor.id,
        purchase_order_lines_attributes: {
          "0" => {
            id: @line_to_keep.id,
            product_variant_id: @variant.id,
            quantity_ordered: 2,
            unit_list_price_cents: 2000,
            supplier_discount_bps: 4000,
            unit_cost_cents: 1500,
            manual_cost_override: true,
            manual_price_override: false,
            _destroy: "0"
          },
          "1" => {
            id: @line_to_remove.id,
            product_variant_id: @variant.id,
            quantity_ordered: 1,
            _destroy: "1"
          }
        }
      }
    }

    assert_redirected_to orders_purchase_order_path(@purchase_order)
    line = @line_to_keep.reload
    assert_equal 1500, line.unit_cost_cents
    assert line.manual_cost_override
    assert_equal "manual", line.cost_source
  end

  test "update marks supplier discount edit as manual cost override" do
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "VEND-1",
      supplier_discount_bps: 4000,
      returnability_status: "returnable",
      active: true
    )
    @variant.product.update!(list_price_cents: 2000)

    patch orders_purchase_order_path(@purchase_order), params: {
      purchase_order: {
        vendor_id: @vendor.id,
        purchase_order_lines_attributes: {
          "0" => {
            id: @line_to_keep.id,
            product_variant_id: @variant.id,
            quantity_ordered: 2,
            unit_list_price_cents: 2000,
            supplier_discount_bps: 3000,
            unit_cost_cents: 1400,
            manual_cost_override: true,
            manual_price_override: false,
            _destroy: "0"
          },
          "1" => {
            id: @line_to_remove.id,
            product_variant_id: @variant.id,
            quantity_ordered: 1,
            _destroy: "1"
          }
        }
      }
    }

    assert_redirected_to orders_purchase_order_path(@purchase_order)
    line = @line_to_keep.reload
    assert_equal 3000, line.supplier_discount_bps
    assert_equal 1400, line.unit_cost_cents
    assert line.manual_cost_override
    assert_equal "manual", line.cost_source
  end

  test "update preserves both manual cost and retail overrides in one save" do
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "VEND-1",
      supplier_discount_bps: 4000,
      returnability_status: "returnable",
      active: true
    )
    @variant.product.update!(list_price_cents: 2000)

    patch orders_purchase_order_path(@purchase_order), params: {
      purchase_order: {
        vendor_id: @vendor.id,
        purchase_order_lines_attributes: {
          "0" => {
            id: @line_to_keep.id,
            product_variant_id: @variant.id,
            quantity_ordered: 2,
            unit_list_price_cents: 2000,
            supplier_discount_bps: 4000,
            unit_cost_cents: 1500,
            expected_retail_price_cents: 3200,
            manual_cost_override: true,
            manual_price_override: true,
            _destroy: "0"
          },
          "1" => {
            id: @line_to_remove.id,
            product_variant_id: @variant.id,
            quantity_ordered: 1,
            _destroy: "1"
          }
        }
      }
    }

    assert_redirected_to orders_purchase_order_path(@purchase_order)
    line = @line_to_keep.reload
    assert_equal 1500, line.unit_cost_cents
    assert_equal 3200, line.expected_retail_price_cents
    assert line.manual_cost_override
    assert line.manual_price_override
    assert_equal "manual", line.cost_source
    assert_equal "manual", line.price_source
  end

  test "update preserves manual expected retail override" do
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "VEND-1",
      supplier_discount_bps: 4000,
      returnability_status: "returnable",
      active: true
    )

    patch orders_purchase_order_path(@purchase_order), params: {
      purchase_order: {
        vendor_id: @vendor.id,
        purchase_order_lines_attributes: {
          "0" => {
            id: @line_to_keep.id,
            product_variant_id: @variant.id,
            quantity_ordered: 2,
            expected_retail_price_cents: 3200,
            manual_cost_override: false,
            manual_price_override: true,
            _destroy: "0"
          },
          "1" => {
            id: @line_to_remove.id,
            product_variant_id: @variant.id,
            quantity_ordered: 1,
            _destroy: "1"
          }
        }
      }
    }

    assert_redirected_to orders_purchase_order_path(@purchase_order)
    line = @line_to_keep.reload
    assert_equal 3200, line.expected_retail_price_cents
    assert line.manual_price_override
    assert_equal "manual", line.price_source
  end

  test "update ignores blank added line rows" do
    patch orders_purchase_order_path(@purchase_order), params: {
      purchase_order: {
        vendor_id: @vendor.id,
        purchase_order_lines_attributes: {
          "0" => {
            id: @line_to_keep.id,
            product_variant_id: @variant.id,
            quantity_ordered: 2,
            _destroy: "0"
          },
          "1" => {
            id: @line_to_remove.id,
            product_variant_id: @variant.id,
            quantity_ordered: 1,
            _destroy: "1"
          },
          "2" => {
            product_variant_id: "",
            quantity_ordered: "",
            _destroy: "0"
          }
        }
      }
    }

    assert_redirected_to orders_purchase_order_path(@purchase_order)
    assert_equal 1, @purchase_order.reload.purchase_order_lines.count
  end

  test "close marks submitted purchase order closed" do
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "VEND-1",
      supplier_discount_bps: 4000,
      returnability_status: "returnable",
      active: true
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @purchase_order, submitted_by_user: @user)

    patch close_orders_purchase_order_path(@purchase_order)

    assert_redirected_to orders_purchase_order_path(@purchase_order)
    assert_equal "closed", @purchase_order.reload.status
    assert_equal "closed", @purchase_order.purchase_order_lines.first.status
  end

  test "from tbo lists buildable lines for selected vendor" do
    variant_two = create_product_variant!(sub_department: @sub_department, inventory_behavior: "standard_physical")
    request_one = PurchaseRequest.create!(store: @store, status: "open")
    line_one = request_one.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 2,
      status: "open"
    )
    request_two = PurchaseRequest.create!(store: @store, status: "open")
    line_two = request_two.purchase_request_lines.create!(
      product_variant: variant_two,
      requested_quantity: 5,
      status: "open"
    )

    get from_tbo_orders_purchase_orders_path(vendor_id: @vendor.id)

    assert_response :success
    assert_match @variant.sku, response.body
    assert_match variant_two.sku, response.body
    assert_match "purchase_request_line_#{line_one.id}", response.body
    assert_match "purchase_request_line_#{line_two.id}", response.body
    assert_match "On hand", response.body
    assert_match "On order", response.body
    assert_match "Order qty", response.body
  end

  test "from tbo suggested view groups lines by suggested vendor" do
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "VEND-1",
      active: true,
      preferred: true
    )
    request = PurchaseRequest.create!(store: @store, status: "open")
    request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 2,
      status: "open"
    )

    get from_tbo_orders_purchase_orders_path(view: "suggested")

    assert_response :success
    assert_match @vendor.name, response.body
    assert_match "Suggested vendor view", response.body
  end

  test "create from tbo supports partial order quantity" do
    request = PurchaseRequest.create!(store: @store, status: "open")
    line = request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 10,
      status: "open"
    )

    post create_from_tbo_orders_purchase_orders_path, params: {
      vendor_id: @vendor.id,
      purchase_request_line_ids: [ line.id ],
      line_quantities: { line.id => 4 }
    }

    purchase_order = PurchaseOrder.order(:id).last
    assert_redirected_to orders_purchase_order_path(purchase_order)
    assert_equal 4, purchase_order.purchase_order_lines.first.quantity_ordered
    assert_equal "partially_ordered", line.reload.status
    assert_equal "partially_ordered", request.reload.status
  end

  test "create from tbo combines lines from multiple purchase requests" do
    variant_two = create_product_variant!(sub_department: @sub_department, inventory_behavior: "standard_physical")
    request_one = PurchaseRequest.create!(store: @store, status: "open")
    line_one = request_one.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 2,
      status: "open"
    )
    request_two = PurchaseRequest.create!(store: @store, status: "open")
    line_two = request_two.purchase_request_lines.create!(
      product_variant: variant_two,
      requested_quantity: 5,
      status: "open"
    )

    post create_from_tbo_orders_purchase_orders_path, params: {
      vendor_id: @vendor.id,
      purchase_request_line_ids: [ line_one.id, line_two.id ],
      notes: "Combined TBO"
    }

    purchase_order = PurchaseOrder.order(:id).last
    assert_redirected_to orders_purchase_order_path(purchase_order)
    assert_equal "Combined TBO", purchase_order.notes
    assert_equal 2, purchase_order.purchase_order_lines.count
    assert_equal "added_to_po", line_one.reload.status
    assert_equal "added_to_po", line_two.reload.status
    assert_equal "added_to_po", request_one.reload.status
    assert_equal "added_to_po", request_two.reload.status
  end

  test "show displays metric strip and variant names" do
    @line_to_keep.update!(
      unit_list_price_cents: 2000,
      unit_cost_cents: 1200,
      variant_name_snapshot: @variant.name
    )
    @line_to_remove.destroy!

    get orders_purchase_order_path(@purchase_order)

    assert_response :success
    assert_select ".ss-metric-strip"
    assert_match "Total cost", response.body
    assert_match @variant.name, response.body
    assert_match "$24.00", response.body
    assert_match "40.00%", response.body
  end

  test "receive creates draft receipt from submitted purchase order" do
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "VEND-1",
      supplier_discount_bps: 4000,
      returnability_status: "returnable",
      active: true
    )
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 4) ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: order, submitted_by_user: @user)

    post receive_orders_purchase_order_path(order)

    receipt = Receipt.order(:id).last
    assert_redirected_to edit_orders_receipt_path(receipt)
    assert_equal "po_backed", receipt.receipt_type
    assert_equal 1, receipt.receipt_lines.count
    assert_equal 4, receipt.receipt_lines.first.quantity_expected
  end
end
