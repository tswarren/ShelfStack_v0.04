# frozen_string_literal: true

require "test_helper"

class PurchasingAddDemandToPurchaseOrderTest < ActiveSupport::TestCase
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
    @purchase_order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 1) ]
    )
  end

  test "adds demand quantity to existing draft PO line" do
    Purchasing::AddDemandToPurchaseOrder.call!(
      purchase_order: @purchase_order,
      created_by_user: @user,
      demand_line_ids: [ @demand.id ]
    )

    line = @purchase_order.purchase_order_lines.first.reload
    assert_equal 3, line.quantity_ordered
    assert AuditEvent.exists?(event_name: "purchase_order.demand_added", auditable: @purchase_order)
  end

  test "rejects non-draft purchase order" do
    @purchase_order.update!(status: "submitted")

    assert_raises(Purchasing::AddDemandToPurchaseOrder::AddError) do
      Purchasing::AddDemandToPurchaseOrder.call!(
        purchase_order: @purchase_order,
        created_by_user: @user,
        demand_line_ids: [ @demand.id ]
      )
    end
  end
end
