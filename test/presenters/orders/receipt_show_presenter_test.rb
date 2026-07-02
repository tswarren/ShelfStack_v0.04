# frozen_string_literal: true

require "test_helper"

class Orders::ReceiptShowPresenterTest < ActiveSupport::TestCase
  include Phase7aTestHelper
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
    @draft_po = PurchaseOrder.create!(
      store: @store,
      vendor: @vendor,
      status: "draft",
      purchase_order_lines: [
        PurchaseOrderLine.new(
          line_number: 1,
          product_variant: @variant,
          vendor: @vendor,
          quantity_ordered: 2,
          quantity_received: 0,
          cost_source: "unknown",
          price_source: "unknown"
        )
      ]
    )
    @po_line = @draft_po.purchase_order_lines.first
    @demand_line = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: @customer,
      quantity: 1
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @draft_po, submitted_by_user: @user)
    DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: @demand_line,
      purchase_order_line: @po_line,
      actor: @user,
      quantity: 1
    )
    @receipt = Receipt.create!(
      store: @store,
      vendor: @vendor,
      purchase_order: @draft_po.reload,
      receipt_type: "po_backed",
      status: "draft",
      receipt_lines: [
        ReceiptLine.new(
          line_number: 1,
          product_variant: @variant,
          purchase_order_line: @po_line,
          quantity_expected: 2,
          quantity_received: 2,
          quantity_accepted: 2,
          quantity_rejected: 0,
          unit_cost_cents: 1000
        )
      ]
    )
    @document_hub = Purchasing::ReceiptDocumentHub.call(@receipt)
  end

  test "draft receipt uses projected stock quantity label" do
    presenter = Orders::ReceiptShowPresenter.new(receipt: @receipt, document_hub: @document_hub)

    assert_equal "Projected stock quantity", presenter.stock_quantity_label
    assert presenter.pre_post_allocation_message.present?
    assert_equal 1, presenter.allocation_summary_rows.first[:customer_quantity]
    assert_equal 1, presenter.allocation_summary_rows.first[:stock_quantity]
  end

  test "posted receipt uses actual stock quantity label" do
    @receipt.update!(status: "posted")
    presenter = Orders::ReceiptShowPresenter.new(receipt: @receipt.reload, document_hub: @document_hub)

    assert_equal "Actual stock quantity", presenter.stock_quantity_label
  end

  test "posted receipt shows actual customer allocations after post" do
    Current.store = @store
    Purchasing::PostReceipt.call(receipt: @receipt, posted_by_user: @user)
    document_hub = Purchasing::ReceiptDocumentHub.call(@receipt.reload)
    presenter = Orders::ReceiptShowPresenter.new(receipt: @receipt, document_hub: document_hub)

    assert_equal "Actual stock quantity", presenter.stock_quantity_label
    assert presenter.customer_allocation_rows.any?
    assert_equal "actual", presenter.customer_allocation_rows.first[:state]
    assert_equal 1, presenter.allocation_summary_rows.first[:customer_quantity]
    assert_equal 1, presenter.allocation_summary_rows.first[:stock_quantity]
    assert_nil presenter.pre_post_allocation_message
  end

  test "po allocation rows expose allocated received and remaining" do
    presenter = Orders::ReceiptShowPresenter.new(receipt: @receipt, document_hub: @document_hub)

    row = presenter.po_allocation_rows.first
    assert_equal 1, row[:quantity_allocated]
    assert_equal 0, row[:quantity_received]
    assert_equal 1, row[:quantity_remaining]
    assert_equal @customer.display_name, row[:customer_name]
  end

  test "projected allocation rows omit nil entries when accepted qty is less than allocations" do
    customer_two = create_customer!
    demand_line_two = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: customer_two,
      quantity: 1
    )
    DemandAllocations::AllocateInboundPurchaseOrder.call!(
      demand_line: demand_line_two,
      purchase_order_line: @po_line,
      actor: @user,
      quantity: 1
    )
    @receipt.receipt_lines.first.update!(quantity_accepted: 1)

    presenter = Orders::ReceiptShowPresenter.new(receipt: @receipt.reload, document_hub: @document_hub)
    rows = presenter.customer_allocation_rows

    assert rows.all?
    assert_equal 1, rows.size
    assert_equal 1, rows.sum { |row| row[:quantity] }
  end
end
