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

  test "rejects inbound allocation beyond unallocated demand quantity" do
    assert_raises(DemandAllocations::AllocateInboundPurchaseOrder::AllocateError) do
      DemandAllocations::AllocateInboundPurchaseOrder.call!(
        demand_line: @demand_line,
        purchase_order_line: @po_line,
        actor: @user,
        quantity: 3
      )
    end
  end

  test "rejects inbound allocation for draft purchase order" do
    draft_order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 3) ]
    )
    draft_line = draft_order.purchase_order_lines.first

    assert_raises(DemandAllocations::AllocateInboundPurchaseOrder::AllocateError) do
      DemandAllocations::AllocateInboundPurchaseOrder.call!(
        demand_line: @demand_line,
        purchase_order_line: draft_line,
        actor: @user,
        quantity: 1
      )
    end
  end

  test "rejects inbound allocation for used wanted demand" do
    used_condition = ProductCondition.find_by(condition_key: "used_good") ||
      create_product_condition!(condition_key: "used_good_inbound", name: "Used Good", short_name: "Used",
                                new_condition: false, buyback_eligible: true)
    used_variant = create_product_variant!(
      product: @variant.product,
      condition: used_condition,
      inventory_behavior: "standard_physical",
      sku: "211#{SecureRandom.random_number(10**10).to_s.rjust(10, '0')}"
    )

    used_demand = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "used_wanted",
      variant: used_variant,
      customer: create_customer!(display_name: "Used Buyer"),
      quantity: 1
    )

    error = assert_raises(DemandAllocations::AllocateInboundPurchaseOrder::AllocateError) do
      DemandAllocations::AllocateInboundPurchaseOrder.call!(
        demand_line: used_demand,
        purchase_order_line: @po_line,
        actor: @user,
        quantity: 1
      )
    end

    assert_match(/used-wanted/i, error.message)
  end
end
