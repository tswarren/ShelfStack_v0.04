# frozen_string_literal: true

require "test_helper"

class OrdersPurchasingWorkflowIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
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
      supplier_discount_bps: 4000,
      returnability_status: "returnable",
      active: true
    )
    Current.store = @store
  end

  test "tbo through receive and return to vendor workflow" do
    request = PurchaseRequest.create!(store: @store, status: "open")
    request_line = request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 8,
      request_reason: "tbo",
      status: "open"
    )
    assert_equal 0, InventoryBalance.where(store: @store, product_variant: @variant).count

    order = Purchasing::BuildPurchaseOrder.call(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      purchase_request_lines: [ request_line ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: order, submitted_by_user: @user)
    po_line = order.purchase_order_lines.first

    receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { receipt_type: "po_backed", purchase_order: order },
      lines: [
        {
          product_variant: @variant,
          purchase_order_line: po_line,
          quantity_expected: 8,
          quantity_received: 8,
          quantity_accepted: 8,
          quantity_rejected: 0,
          unit_cost_cents: 1200
        }
      ]
    )
    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 8, balance.quantity_on_hand
    assert_equal 1200, balance.moving_average_unit_cost_cents
    assert_equal "received", order.reload.status
    assert_equal "added_to_po", request_line.reload.status

    rtv = create_return_to_vendor!(
      store: @store,
      vendor: @vendor,
      lines: [ { product_variant: @variant, quantity: 3 } ]
    )
    Purchasing::PostReturnToVendor.call(return_to_vendor: rtv, posted_by_user: @user)

    assert_equal 5, balance.reload.quantity_on_hand
    assert AuditEvent.exists?(event_name: "purchase_order.submitted", auditable: order)
    assert AuditEvent.exists?(event_name: "receipt.posted", auditable: receipt)
    assert AuditEvent.exists?(event_name: "return_to_vendor.posted", auditable: rtv)
  end

  test "purchase order submit via http" do
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 2) ]
    )

    patch submit_orders_purchase_order_path(order)

    assert_redirected_to orders_purchase_order_path(order)
    assert_equal "submitted", order.reload.status
    assert_equal @variant.sku, order.purchase_order_lines.first.variant_sku_snapshot
  end
end
