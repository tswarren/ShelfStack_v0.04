# frozen_string_literal: true

require "test_helper"

class PurchasingBuildPurchaseOrderFromDemandTest < ActiveSupport::TestCase
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
  end

  test "creates draft PO from demand without inbound allocation" do
    purchase_order = Purchasing::BuildPurchaseOrderFromDemand.call!(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      demand_line_ids: [ @demand.id ]
    )

    assert purchase_order.draft?
    assert_equal 1, purchase_order.purchase_order_lines.count
    assert_equal 2, purchase_order.purchase_order_lines.first.quantity_ordered
    assert_equal 0, DemandAllocation.active_allocations.inbound_kind.where(demand_line: @demand).count
    assert AuditEvent.exists?(event_name: "purchase_order.created_from_demand", auditable: purchase_order)
  end

  test "translates BuildPurchaseOrder eligibility failure" do
    @variant.update!(orderable: false)

    error = assert_raises(Purchasing::BuildPurchaseOrderFromDemand::BuildError) do
      Purchasing::BuildPurchaseOrderFromDemand.call!(
        store: @store,
        vendor: @vendor,
        created_by_user: @user,
        demand_line_ids: [ @demand.id ]
      )
    end

    assert_match(/not orderable/i, error.message)
  end

  test "aggregates multiple demand lines for same variant" do
    demand_b = DemandLines::Create.call!(
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
      demand_line_ids: [ @demand.id, demand_b.id ]
    )

    assert_equal 1, purchase_order.purchase_order_lines.count
    assert_equal 3, purchase_order.purchase_order_lines.first.quantity_ordered
  end
end
