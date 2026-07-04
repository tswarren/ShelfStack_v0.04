# frozen_string_literal: true

require "test_helper"

class Orders::ReceiptShowPresenterMatchAwareTest < ActiveSupport::TestCase
  include Phase7aTestHelper
  include Phase5TestHelper
  include V0047TestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    seed_v0047_permissions!
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @user = create_user!
    grant_v0047_allocation_permissions!(@user, store: @store)
    @vendor = create_vendor!
    @variant = create_product_variant!
    @customer = create_customer!
    @purchase_order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [
        create_purchase_order_line_attrs(
          variant: @variant,
          vendor: @vendor,
          quantity_ordered: 2,
          quantity_received: 0
        )
      ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @purchase_order, submitted_by_user: @user)
    @po_line = @purchase_order.purchase_order_lines.first
    @demand_line = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: @customer,
      quantity: 1
    )
    DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: @demand_line,
      purchase_order_line: @po_line,
      actor: @user,
      quantity: 1
    )
    @receipt = Receiving::CreateVendorShipmentReceipt.call!(
      store: @store,
      vendor: @vendor,
      attrs: {}
    )
    @receipt_line = @receipt.receipt_lines.create!(
      product_variant: @variant,
      quantity_expected: 0,
      quantity_received: 2,
      quantity_accepted: 2,
      quantity_rejected: 0,
      unit_cost_cents: 1000
    )
    Receiving::ApplyReceiptLineMatches.call!(
      receipt: @receipt,
      actor: @user,
      matches: [
        {
          receipt_line_id: @receipt_line.id,
          purchase_order_line_id: @po_line.id,
          quantity_matched: 2
        }
      ]
    )
    @document_hub = Purchasing::ReceiptDocumentHub.call(@receipt.reload)
  end

  test "shows po alignment and projected customer allocations from receipt line matches" do
    presenter = Orders::ReceiptShowPresenter.new(receipt: @receipt, document_hub: @document_hub)

    assert presenter.show_po_alignment?
    assert presenter.pre_post_allocation_message.present?
    assert_equal 1, presenter.allocation_summary_rows.first[:customer_quantity]
    assert_equal 1, presenter.allocation_summary_rows.first[:stock_quantity]
    assert_equal @purchase_order.id, presenter.po_allocation_rows.first[:purchase_order_id]
  end
end
