# frozen_string_literal: true

require "test_helper"

class DemandAllocationsInboundAvailabilityTest < ActiveSupport::TestCase
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
    @demand_line = create_open_demand_line!(store: @store, actor: @user, variant: @variant, quantity: 5)
  end

  test "available_for floors at zero while raw overclaim is detectable" do
    DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: @demand_line,
      purchase_order_line: @po_line,
      actor: @user,
      quantity: 4
    )
    record_po_line_vendor_quantities!(@po_line, confirmed: 2)

    availability = DemandAllocations::InboundAvailability.new(purchase_order_line: @po_line.reload)

    assert_equal 0, availability.available_for
    assert_equal(-2, availability.raw_open_for_inbound_allocation)
    assert_equal 2, availability.overclaimed_quantity
  end
end
