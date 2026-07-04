# frozen_string_literal: true

require "test_helper"

class PurchasingPurchaseOrderSubmitImpactPreviewTest < ActiveSupport::TestCase
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
    @demand = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: create_customer!,
      quantity: 2
    )
    @purchase_order = Purchasing::BuildPurchaseOrderFromDemand.call!(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      demand_line_ids: [ @demand.id ]
    )
  end

  test "preview summarizes planned customer inbound conversion for draft PO" do
    preview = Purchasing::PurchaseOrderSubmitImpactPreview.call(purchase_order: @purchase_order)

    assert_equal 2, preview.total_planned_copies
    assert_equal 2, preview.customer_inbound_copies
    assert_includes preview.message, "customer"
  end

  test "returns nil for submitted PO" do
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @purchase_order, submitted_by_user: @user)

    assert_nil Purchasing::PurchaseOrderSubmitImpactPreview.call(purchase_order: @purchase_order.reload)
  end
end
