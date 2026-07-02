# frozen_string_literal: true

require "test_helper"

class DemandLinesQueueScopeTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase4TestHelper
  include Phase5TestHelper
  include Phase5TestHelper
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    grant_v0047_allocation_permissions!(@user, store: @store)
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 10)
  end

  test "ready_for_pickup includes active on-hand allocation" do
    demand_line = create_hold_demand!(quantity: 1)

    ids = scoped_ids("ready_for_pickup")

    assert_includes ids, demand_line.id
  end

  test "needs_research includes captured unmatched demand" do
    demand_line = DemandLines::CreateFromProvisional.call!(
      store: @store,
      actor: @user,
      customer: create_customer!,
      provisional_title: "Unknown Book",
      quantity: 1
    )

    ids = scoped_ids("needs_research")

    assert_includes ids, demand_line.id
  end

  test "notify_customer includes notify intent with on-hand stock" do
    demand_line = DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      capture_intent: "notify",
      quantity: 1,
      customer: create_customer!
    ).demand_line
    DemandAllocations::AllocateOnHand.call!(demand_line: demand_line, actor: @user, quantity: 1)

    ids = scoped_ids("notify_customer")

    assert_includes ids, demand_line.id
  end

  test "on_order includes active inbound allocation" do
    demand_line = create_open_demand_line!(store: @store, actor: @user, variant: @variant, capture_intent: "special_order", quantity: 2)
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 5) ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: order, submitted_by_user: @user)
    po_line = order.purchase_order_lines.first
    DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: demand_line,
      purchase_order_line: po_line,
      actor: @user,
      quantity: 2
    )

    ids = scoped_ids("on_order")

    assert_includes ids, demand_line.id
  end

  private

  def create_hold_demand!(quantity:)
    DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      capture_intent: "hold",
      quantity: quantity,
      customer: create_customer!
    ).demand_line
  end

  def scoped_ids(queue_key)
    DemandLines::QueueScope.apply(DemandLine.where(store: @store), queue_key, store: @store).pluck(:id)
  end
end
