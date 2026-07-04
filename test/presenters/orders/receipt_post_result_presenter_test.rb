# frozen_string_literal: true

require "test_helper"

class OrdersReceiptPostResultPresenterTest < ActiveSupport::TestCase
  include Phase7aTestHelper
  include Phase5TestHelper

  setup do
    seed_phase3_reference_data!
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    ProductVendor.create!(product: @variant.product, vendor: @vendor, active: true, preferred: true)
  end

  test "presenter exposes inventory increase and customer-ready rows after post" do
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
    Purchasing::SubmitPurchaseOrder.call(purchase_order: purchase_order, submitted_by_user: @user)
    po_line = purchase_order.purchase_order_lines.first

    receipt = Receiving::CreateVendorShipmentReceipt.call!(store: @store, vendor: @vendor, attrs: {})
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
      matches: [ { receipt_line_id: receipt_line.id, purchase_order_line_id: po_line.id, quantity_matched: 1 } ]
    )
    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)

    presenter = Orders::ReceiptPostResultPresenter.new(
      receipt: receipt.reload,
      document_hub: Purchasing::ReceiptDocumentHub.call(receipt)
    )

    assert_equal 1, presenter.inventory_increase
    assert presenter.customer_ready_rows.any? { |row| row[:demand_number] == demand.demand_number }
  end
end
