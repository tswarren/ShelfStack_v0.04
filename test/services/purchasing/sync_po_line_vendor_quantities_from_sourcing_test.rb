# frozen_string_literal: true

require "test_helper"

class PurchasingSyncPoLineVendorQuantitiesFromSourcingTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase5TestHelper
  include V0047TestHelper
  include V0048TestHelper
  include V0049TestHelper

  setup do
    seed_v0047_permissions!
    seed_v0048_permissions!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!
    @demand_line = create_open_demand_line!(store: @store, actor: @user, variant: @variant, quantity: 5)
    @order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 5) ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @order, submitted_by_user: @user)
    @po_line = @order.purchase_order_lines.first
    @run = Sourcing::StartRun.call!(demand_line: @demand_line, actor: @user)
    @attempt = Sourcing::CreateAttempt.call!(sourcing_run: @run, actor: @user, vendor: @vendor, quantity: 5)
    Sourcing::SubmitAttempt.call!(sourcing_attempt: @attempt, actor: @user)
  end

  test "sync aggregates final vendor responses idempotently" do
    response = Sourcing::RecordVendorResponse.call!(
      sourcing_attempt: @attempt,
      actor: @user,
      purchase_order_line: @po_line,
      quantity_confirmed: 3,
      quantity_backordered: 2,
      final_response: true
    )

    @po_line.reload
    assert_equal 3, @po_line.quantity_confirmed_by_vendor
    assert_equal 2, @po_line.quantity_backordered_by_vendor
    assert_equal 0, @po_line.quantity_canceled_by_vendor
    assert @po_line.vendor_quantities_recorded_at.present?
    assert_equal "mixed", @po_line.vendor_quantity_state
    assert_equal "sourcing_response", @po_line.vendor_quantities_source_type
    assert_equal response.id, @po_line.vendor_quantities_source_id

    Purchasing::SyncPoLineVendorQuantitiesFromSourcing.call!(purchase_order_line: @po_line, source_response: response)
    @po_line.reload
    assert_equal 3, @po_line.quantity_confirmed_by_vendor
    assert_equal 2, @po_line.quantity_backordered_by_vendor
  end

  test "non-final response does not sync via record vendor response hook" do
    Sourcing::RecordVendorResponse.call!(
      sourcing_attempt: @attempt,
      actor: @user,
      purchase_order_line: @po_line,
      quantity_confirmed: 2,
      final_response: false
    )

    @po_line.reload
    assert_nil @po_line.vendor_quantities_recorded_at
    assert_equal 0, @po_line.quantity_confirmed_by_vendor
  end
end
