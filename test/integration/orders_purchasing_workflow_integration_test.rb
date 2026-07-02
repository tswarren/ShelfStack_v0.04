# frozen_string_literal: true

require "test_helper"

class OrdersPurchasingWorkflowIntegrationTest < ActionDispatch::IntegrationTest
  include Phase7aTestHelper

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

  test "manual tbo through receive and return to vendor workflow" do
    create_manual_tbo_demand!(store: @store, actor: @user, variant: @variant, quantity: 8)
    assert_equal 0, InventoryBalance.where(store: @store, product_variant: @variant).count

    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 8) ]
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
