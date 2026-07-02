# frozen_string_literal: true

require "test_helper"

class OrdersDocumentHubIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "items.catalog_items.view", store: @store)
    login_user!(@user, workstation: @workstation)

    @vendor = create_vendor!
    @variant = create_product_variant!
    @purchase_order = Purchasing::BuildPurchaseOrder.call(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      manual_lines: [
        {
          product_variant_id: @variant.id,
          quantity_ordered: 4,
          line_number: 1
        }
      ]
    )
    @purchase_order.purchase_order_lines.first.update!(
      quantity_received: 2,
      unit_list_price_cents: 2000,
      unit_cost_cents: 1200,
      variant_name_snapshot: @variant.name,
      variant_sku_snapshot: @variant.sku
    )
    @receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { purchase_order: @purchase_order, receipt_type: "po_backed", status: "posted" },
      lines: [
        {
          product_variant: @variant,
          purchase_order_line: @purchase_order.purchase_order_lines.first,
          quantity_expected: 2,
          quantity_received: 1,
          quantity_accepted: 1,
          quantity_rejected: 0,
          unit_cost_cents: 1200
        }
      ]
    )
    ReceivingDiscrepancy.create!(
      receipt_line: @receipt.receipt_lines.first,
      discrepancy_type: "short",
      quantity_delta: -1
    )
  end

  test "purchase order show uses progressive disclosure layout" do
    get orders_purchase_order_path(@purchase_order)

    assert_response :success
    assert_select ".ss-metric-strip"
    assert_select ".ss-document-layout"
    assert_select ".ss-document-trail"
    assert_match "Ordered", response.body
    assert_match "Open", response.body
    assert_match "Related documents (detail)", response.body
    assert_match "Line receipt activity", response.body
    assert_match "Receiving discrepancies", response.body
    assert_match @variant.name, response.body
    assert_match "href=\"/items/item", response.body
    assert_lines_before_collapsible_audit
  end

  test "receipt show uses progressive disclosure layout" do
    get orders_receipt_path(@receipt)

    assert_response :success
    assert_select ".ss-metric-strip"
    assert_select ".ss-document-layout"
    assert_match "Expected", response.body
    assert_match "Accepting", response.body
    assert_match "PO line alignment", response.body
    assert_match "Receiving discrepancies", response.body
    assert_match @variant.name, response.body
    assert_lines_before_collapsible_audit
  end

  private

  def assert_lines_before_collapsible_audit
    lines_index = response.body.index("<h2>Lines</h2>")
    audit_index = response.body.index('class="ss-collapsible-panel"')
    assert lines_index, "expected Lines heading"
    assert audit_index, "expected collapsible audit panel"
    assert_operator lines_index, :<, audit_index
  end
end
