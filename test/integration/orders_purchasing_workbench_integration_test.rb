# frozen_string_literal: true

require "test_helper"

class OrdersPurchasingWorkbenchIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase5_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)

    @vendor = create_vendor!(default_supplier_discount_bps: 4000)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @variant.product.update!(list_price_cents: 2000)
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "WB-VEND-1",
      supplier_discount_bps: 4000,
      returnability_status: "returnable",
      active: true
    )
  end

  test "purchase order form renders purchasing line table" do
    get new_orders_purchase_order_path

    assert_response :success
    assert_match "ss-purchasing-table", response.body
    assert_match "purchasing-line-table", response.body
    assert_match "Scan", response.body
    assert_match "Unit cost", response.body
    assert_match "toggleDetails", response.body
    assert_match "pricingFieldChanged", response.body
  end

  test "create purchase order via nested line table attributes" do
    post orders_purchase_orders_path, params: {
      purchase_order: {
        vendor_id: @vendor.id,
        notes: "Table entry",
        purchase_order_lines_attributes: {
          "0" => {
            product_variant_id: @variant.id,
            quantity_ordered: 3,
            unit_list_price_cents: 2000,
            supplier_discount_bps: 4000,
            unit_cost_cents: 1200,
            _destroy: "0"
          }
        }
      }
    }

    order = PurchaseOrder.order(:id).last
    assert_redirected_to orders_purchase_order_path(order)
    assert_equal 1, order.purchase_order_lines.count
    assert_equal 3, order.purchase_order_lines.first.quantity_ordered
  end

  test "receive purchase order flow preloads receipt edit form" do
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 5) ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: order, submitted_by_user: @user)

    post receive_orders_purchase_order_path(order)
    receipt = Receipt.order(:id).last

    assert_redirected_to edit_orders_receipt_path(receipt)

    get edit_orders_receipt_path(receipt)
    assert_response :success
    assert_match "ss-purchasing-table", response.body
    assert_match "Receive all as expected", response.body
    assert_match @variant.sku, response.body
    assert_equal 5, receipt.receipt_lines.first.quantity_expected
  end
end
