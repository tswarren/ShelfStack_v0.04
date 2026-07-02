# frozen_string_literal: true

require "test_helper"

class SourcingRecordVendorResponseTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase5TestHelper
  include V0047TestHelper
  include V0048TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    grant_v0047_allocation_permissions!(@user)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @vendor = create_vendor_for_variant!(@variant)
    @demand = create_special_order_demand!(store: @store, actor: @user, variant: @variant, quantity: 3)
    @run = Sourcing::StartRun.call!(demand_line: @demand, actor: @user, quantity: 3)
    @attempt = Sourcing::CreateAttempt.call!(sourcing_run: @run, actor: @user, vendor: @vendor, quantity: 3)
    Sourcing::SubmitAttempt.call!(sourcing_attempt: @attempt, actor: @user)
    @attempt.reload
    @ledger_before = InventoryLedgerEntry.count
  end

  test "partial final response derives partially_confirmed and needs_review" do
    response = Sourcing::RecordVendorResponse.call!(
      sourcing_attempt: @attempt,
      actor: @user,
      quantity_confirmed: 1,
      quantity_backordered: 1,
      quantity_unavailable: 1,
      final_response: true,
      accept_backorder: true
    )

    assert_equal "partially_confirmed", @attempt.reload.status
    assert @attempt.buyer_review_required?
    assert_equal "needs_review", @run.reload.status
    assert_equal 1, @demand.demand_allocations.active_allocations.vendor_backorder_kind.sum(:quantity_allocated)
    assert_equal "partially_allocated", @demand.reload.status
    assert AuditEvent.exists?(event_name: "vendor_response.recorded", auditable: response)
    assert_equal @ledger_before, InventoryLedgerEntry.count
  end

  test "confirmed without PO line does not create inbound allocation" do
    Sourcing::RecordVendorResponse.call!(
      sourcing_attempt: @attempt,
      actor: @user,
      quantity_confirmed: 2,
      quantity_unavailable: 1,
      final_response: true
    )

    assert_equal 0, @demand.demand_allocations.active_allocations.inbound_kind.count
    assert @attempt.reload.buyer_review_required?
  end

  test "confirmed with linked PO line creates inbound allocation" do
    po = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 5) ]
    )
    po_line = po.purchase_order_lines.first
    po.update!(status: "submitted")

    Sourcing::RecordVendorResponse.call!(
      sourcing_attempt: @attempt,
      actor: @user,
      quantity_confirmed: 3,
      final_response: true,
      purchase_order_line: po_line
    )

    assert_equal 3, @demand.demand_allocations.active_allocations.inbound_kind.sum(:quantity_allocated)
    assert_equal "allocated", @demand.reload.status
  end

  test "vendor backorder does not change inventory reserved cache" do
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 5)
    before = inventory_snapshot(store: @store, variant: @variant)

    Sourcing::RecordVendorResponse.call!(
      sourcing_attempt: @attempt,
      actor: @user,
      quantity_backordered: 3,
      final_response: true,
      accept_backorder: true
    )

    after = inventory_snapshot(store: @store, variant: @variant)
    assert_equal before[:reserved], after[:reserved]
    assert_equal before[:available], after[:available]
    assert_equal "allocated", @demand.reload.status
  end
end
