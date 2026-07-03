# frozen_string_literal: true

require "test_helper"

class ReceivingValidateReceiptLineMatchesTest < ActiveSupport::TestCase
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
    @demand = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: create_customer!,
      quantity: 1
    )
    @purchase_order = Purchasing::BuildPurchaseOrderFromDemand.call!(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      demand_line_ids: [ @demand.id ]
    )
    @purchase_order.purchase_order_lines.first.update!(quantity_ordered: 5)
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @purchase_order, submitted_by_user: @user)
    @po_line = @purchase_order.purchase_order_lines.first
    @receipt = Receiving::CreateVendorShipmentReceipt.call!(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      attrs: {}
    )
    @receipt_line = @receipt.receipt_lines.create!(
      product_variant: @variant,
      quantity_expected: 0,
      quantity_received: 5,
      quantity_accepted: 5,
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
          quantity_matched: 5
        }
      ]
    )
  end

  test "blocks post when accepted quantity drops below matched quantity" do
    @receipt_line.update!(quantity_accepted: 3)

    error = assert_raises(Receiving::ValidateReceiptLineMatches::ValidationError) do
      Receiving::ValidateReceiptLineMatches.call!(receipt: @receipt.reload)
    end

    assert_match(/exceeds accepted quantity/i, error.message)
  end

  test "post receipt surfaces match validation as posting error" do
    @receipt_line.update!(quantity_accepted: 3)

    error = assert_raises(Purchasing::PostReceipt::PostingError) do
      Purchasing::PostReceipt.call(receipt: @receipt.reload, posted_by_user: @user)
    end

    assert_match(/exceeds accepted quantity/i, error.message)
  end
end
