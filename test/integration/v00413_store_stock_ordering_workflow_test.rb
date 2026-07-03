# frozen_string_literal: true

require "test_helper"

class V00413StoreStockOrderingWorkflowTest < ActiveSupport::TestCase
  include Phase7aTestHelper
  include Phase5TestHelper
  include V0047TestHelper

  setup do
    seed_phase3_reference_data!
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    ProductVendor.create!(product: @variant.product, vendor: @vendor, active: true, preferred: true)
  end

  test "golden path demand to pickup readiness" do
    demand = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: create_customer!,
      quantity: 1
    )

    purchase_order = Purchasing::BuildPurchaseOrderFromDemand.call!(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      demand_line_ids: [ demand.id ]
    )
    assert purchase_order.purchase_order_line_demand_plans.active_plans.exists?

    Purchasing::SubmitPurchaseOrder.call(purchase_order: purchase_order, submitted_by_user: @user)
    purchase_order.reload
    po_line = purchase_order.purchase_order_lines.first
    assert DemandAllocation.active_allocations.inbound_kind.where(demand_line: demand, purchase_order_line: po_line).exists?

    receipt = Receiving::CreateVendorShipmentReceipt.call!(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      attrs: { vendor_shipment_reference: "SHIP-001" }
    )
    receipt_line = receipt.receipt_lines.create!(
      product_variant: @variant,
      quantity_expected: 0,
      quantity_received: 1,
      quantity_accepted: 1,
      quantity_rejected: 0,
      unit_cost_cents: 1000
    )

    Receiving::ApplyReceiptLineMatches.call!(
      receipt: receipt,
      actor: @user,
      matches: [
        {
          receipt_line_id: receipt_line.id,
          purchase_order_line_id: po_line.id,
          quantity_matched: 1
        }
      ]
    )

    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)

    on_hand = DemandAllocation.active_allocations.on_hand_kind.where(demand_line: demand)
    assert_equal 1, on_hand.count
    assert_equal 1, on_hand.first.quantity_allocated
  end

  test "post blocked when accepted quantity is reduced below matched quantity" do
    demand = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: create_customer!,
      quantity: 1
    )
    purchase_order = Purchasing::BuildPurchaseOrderFromDemand.call!(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      demand_line_ids: [ demand.id ]
    )
    purchase_order.purchase_order_lines.first.update!(quantity_ordered: 5)
    Purchasing::SubmitPurchaseOrder.call(purchase_order: purchase_order, submitted_by_user: @user)
    po_line = purchase_order.purchase_order_lines.first
    receipt = Receiving::CreateVendorShipmentReceipt.call!(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      attrs: {}
    )
    receipt_line = receipt.receipt_lines.create!(
      product_variant: @variant,
      quantity_expected: 0,
      quantity_received: 5,
      quantity_accepted: 5,
      quantity_rejected: 0,
      unit_cost_cents: 1000
    )
    Receiving::ApplyReceiptLineMatches.call!(
      receipt: receipt,
      actor: @user,
      matches: [ { receipt_line_id: receipt_line.id, purchase_order_line_id: po_line.id, quantity_matched: 5 } ]
    )
    receipt_line.update!(quantity_accepted: 3)

    assert_raises(Purchasing::PostReceipt::PostingError) do
      Purchasing::PostReceipt.call(receipt: receipt.reload, posted_by_user: @user)
    end
  end
end
