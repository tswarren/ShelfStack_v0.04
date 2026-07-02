# frozen_string_literal: true

require "test_helper"

class PurchasingPurchaseOrderLineDemandBreakdownTest < ActiveSupport::TestCase
  include Phase7aTestHelper
  include V0047TestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    grant_v0047_allocation_permissions!(@user, store: @store)
    @vendor = Vendor.first || Vendor.create!(name: "Test Vendor", active: true)
    @variant = create_product_variant!
    @customer = create_customer!
    @demand_line = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: @customer,
      quantity: 2
    )
    @purchase_order = PurchaseOrder.create!(
      store: @store,
      vendor: @vendor,
      status: "draft",
      purchase_order_lines: [
        PurchaseOrderLine.new(
          line_number: 1,
          product_variant: @variant,
          vendor: @vendor,
          quantity_ordered: 3,
          quantity_received: 0,
          unit_cost_cents: 1000,
          variant_sku_snapshot: @variant.sku,
          variant_name_snapshot: @variant.name
        )
      ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @purchase_order, submitted_by_user: @user)
    DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: @demand_line,
      purchase_order_line: @purchase_order.purchase_order_lines.first,
      actor: @user,
      quantity: 2
    )
  end

  test "breakdown reports customer allocated and stock quantities" do
    breakdown = Purchasing::PurchaseOrderLineDemandBreakdown.for(@purchase_order).first

    assert_equal 2, breakdown.demand_allocated_quantity
    assert_equal 1, breakdown.stock_quantity
    assert_equal 1, breakdown.allocation_rows.size
  end
end
