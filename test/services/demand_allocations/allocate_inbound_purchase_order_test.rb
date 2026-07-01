# frozen_string_literal: true

require "test_helper"

class DemandAllocationsAllocateInboundPurchaseOrderTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase5TestHelper
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @demand_line = create_open_demand_line!(store: @store, actor: @user, variant: @variant, quantity: 2)
    @order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 5) ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @order, submitted_by_user: @user)
    @po_line = @order.purchase_order_lines.first
    @qty_before = @po_line.quantity_ordered
  end

  test "creates inbound allocation without mutating PO line" do
    allocation = DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: @demand_line,
      purchase_order_line: @po_line,
      actor: @user,
      quantity: 2
    )

    @po_line.reload
    assert_equal @qty_before, @po_line.quantity_ordered
    assert_equal "inbound_purchase_order", allocation.allocation_kind
    assert_equal "allocated", @demand_line.reload.status
    assert_no_difference -> { PurchaseOrderLineAllocation.count } do
      assert PurchaseOrderLineAllocation.none?
    end
  end
end
