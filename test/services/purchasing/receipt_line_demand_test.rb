# frozen_string_literal: true

require "test_helper"

class PurchasingReceiptLineDemandTest < ActiveSupport::TestCase
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    grant_v0047_allocation_permissions!(@user, store: @store)
    @vendor = create_vendor!
    @variant = create_product_variant!
    @demand_line = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      quantity: 2,
      variant: @variant,
      customer: create_customer!
    )
    @po_line = PurchaseOrderLine.new(
      line_number: 1,
      product_variant: @variant,
      vendor: @vendor,
      quantity_ordered: 2,
      quantity_received: 0,
      unit_cost_cents: 500,
      variant_sku_snapshot: @variant.sku,
      variant_name_snapshot: @variant.name
    )
    @purchase_order = PurchaseOrder.create!(store: @store, vendor: @vendor, status: "submitted", purchase_order_lines: [ @po_line ])
    DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: @demand_line,
      purchase_order_line: @po_line,
      actor: @user,
      quantity: 2
    )
  end

  test "customer_reserved_open sums open inbound allocation quantity" do
    assert_equal 2, Purchasing::ReceiptLineDemand.customer_reserved_open(@po_line)
  end
end
