# frozen_string_literal: true

require "test_helper"

class DemandAllocationsReleaseUncoveredInboundTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase5TestHelper
  include V0047TestHelper
  include V0049TestHelper

  setup do
    seed_v0047_permissions!
    grant_v0047_allocation_permissions!(@user = create_user!)
    @store = create_store!
    @vendor = create_vendor!
    @variant = create_product_variant!
    @order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 5) ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @order, submitted_by_user: @user)
    @po_line = @order.purchase_order_lines.first
    @demand_a = create_open_demand_line!(store: @store, actor: @user, variant: @variant, quantity: 3)
    @demand_b = create_open_demand_line!(store: @store, actor: @user, variant: @variant, quantity: 3)
    @inbound_a = DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: @demand_a, purchase_order_line: @po_line, actor: @user, quantity: 2
    )
    @inbound_b = DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: @demand_b, purchase_order_line: @po_line, actor: @user, quantity: 1
    )
  end

  test "releases uncovered inbound reverse FIFO when supply drops" do
    record_po_line_vendor_quantities!(@po_line, confirmed: 1)

    DemandAllocations::ReleaseUncoveredInbound.call!(
      purchase_order_line: @po_line,
      actor: @user,
      release_reason: "vendor_canceled"
    )

    assert_equal "released", @inbound_b.reload.status
    assert_equal 1, DemandAllocation.active_allocations.inbound_kind.where(purchase_order_line: @po_line).sum(:quantity_allocated)
  end

  test "does not release when rejected quantity alone leaves supply unchanged" do
    assert_no_difference -> { DemandAllocation.active_allocations.inbound_kind.count } do
      DemandAllocations::ReleaseUncoveredInbound.call!(
        purchase_order_line: @po_line,
        actor: @user,
        release_reason: "receipt_short"
      )
    end
  end
end
