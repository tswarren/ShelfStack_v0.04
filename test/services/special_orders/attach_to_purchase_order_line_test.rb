# frozen_string_literal: true

require "test_helper"

class SpecialOrdersAttachToPurchaseOrderLineTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @other_store = create_store!(store_number: SecureRandom.random_number(100..999).to_s.rjust(3, "0"), name: "Other Store")
    @user = create_user!
    @vendor = create_vendor!
    @other_vendor = create_vendor!(name: "Other Vendor")
    @variant = create_product_variant!
    @customer = create_customer!
    @customer_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: @customer,
      lines: [ { request_type: "special_order" } ]
    )
    @line = @customer_request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
    @special_order = SpecialOrders::CreateFromRequestLine.call!(line: @line, created_by_user: @user)
    SpecialOrders::Approve.call!(special_order: @special_order, approved_by_user: @user)
    @draft_po = PurchaseOrder.create!(
      store: @store,
      vendor: @vendor,
      status: "draft",
      purchase_order_lines: [
        PurchaseOrderLine.new(
          line_number: 1,
          product_variant: @variant,
          vendor: @vendor,
          quantity_ordered: 2,
          quantity_received: 0,
          unit_cost_cents: 1000,
          variant_sku_snapshot: @variant.sku,
          variant_name_snapshot: @variant.name
        )
      ]
    )
    @po_line = @draft_po.purchase_order_lines.first
  end

  test "attaches special order to draft purchase order line" do
    allocation = SpecialOrders::AttachToPurchaseOrderLine.call!(
      special_order: @special_order,
      purchase_order_line: @po_line,
      quantity: 1,
      attached_by_user: @user
    )

    assert_equal 1, allocation.quantity_allocated
    assert InventoryReservation.active_incoming.exists?(special_order: @special_order)
  end

  test "rejects store mismatch" do
    other_po = PurchaseOrder.create!(
      store: @other_store,
      vendor: @vendor,
      status: "draft",
      purchase_order_lines: [
        PurchaseOrderLine.new(
          line_number: 1,
          product_variant: @variant,
          vendor: @vendor,
          quantity_ordered: 2,
          quantity_received: 0,
          unit_cost_cents: 1000,
          variant_sku_snapshot: @variant.sku,
          variant_name_snapshot: @variant.name
        )
      ]
    )

    assert_raises(SpecialOrders::AttachToPurchaseOrderLine::AttachError, match: /Store mismatch/) do
      SpecialOrders::AttachToPurchaseOrderLine.call!(
        special_order: @special_order,
        purchase_order_line: other_po.purchase_order_lines.first,
        quantity: 1,
        attached_by_user: @user
      )
    end
  end

  test "rejects non-draft purchase order" do
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @draft_po, submitted_by_user: @user)

    assert_raises(SpecialOrders::AttachToPurchaseOrderLine::AttachError, match: /draft/) do
      SpecialOrders::AttachToPurchaseOrderLine.call!(
        special_order: @special_order,
        purchase_order_line: @po_line,
        quantity: 1,
        attached_by_user: @user
      )
    end
  end

  test "rejects vendor mismatch when special order has vendor" do
    @special_order.update!(vendor: @other_vendor)

    assert_raises(SpecialOrders::AttachToPurchaseOrderLine::AttachError, match: /Vendor mismatch/) do
      SpecialOrders::AttachToPurchaseOrderLine.call!(
        special_order: @special_order,
        purchase_order_line: @po_line,
        quantity: 1,
        attached_by_user: @user
      )
    end
  end
end
