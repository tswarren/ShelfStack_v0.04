# frozen_string_literal: true

require "test_helper"

class PurchasingCreateDemandCoveragePlansPartialIdempotencyTest < ActiveSupport::TestCase
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
      quantity: 5
    )
    @purchase_order = Purchasing::BuildPurchaseOrderFromDemand.call!(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      demand_line_ids: [ @demand.id ]
    )
    @purchase_order.purchase_order_lines.first.update!(quantity_ordered: 3)
    @line_plans = Purchasing::DemandCoveragePlanner.call(
      demand_lines: [ @demand ],
      vendor: @vendor,
      store: @store
    ).line_plans
  end

  test "partial conversion uses distinct remainder idempotency key" do
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @purchase_order, submitted_by_user: @user)
    @purchase_order.reload

    converted = @purchase_order.purchase_order_line_demand_plans.find_by!(status: "converted")
    remainder = @purchase_order.purchase_order_line_demand_plans.active_plans.first

    assert_equal 3, converted.quantity_planned
    assert_equal 2, remainder.quantity_planned
    assert_not_equal converted.idempotency_key, remainder.idempotency_key
    assert_match(/:remainder:#{converted.id}\z/, remainder.idempotency_key)
    assert converted.converted_to_demand_allocation_id.present?
  end

  test "replacing draft coverage does not revive converted plan when remainder is active" do
    po_line = @purchase_order.purchase_order_lines.first
    base_key = "po:#{@purchase_order.id}:line:#{po_line.id}:demand:#{@demand.id}"

    converted = @purchase_order.purchase_order_line_demand_plans.first
    converted.update!(
      status: "converted",
      quantity_planned: 1,
      converted_at: Time.current,
      converted_by_user: @user
    )

    remainder = PurchaseOrderLineDemandPlan.create!(
      store: @store,
      purchase_order: @purchase_order,
      purchase_order_line: po_line,
      demand_line: @demand,
      product: @demand.product,
      product_variant: @variant,
      quantity_planned: 2,
      fulfillment_route: "inbound_to_store",
      coverage_kind: "customer_fulfillment",
      status: "planned",
      created_by_user: @user,
      idempotency_key: "#{base_key}:remainder:#{converted.id}",
      internal_split: true
    )

    Purchasing::ReleaseDemandCoveragePlan.call!(
      purchase_order: @purchase_order,
      actor: @user,
      reason: "Replacing coverage"
    )
    remainder.reload
    assert_equal "released", remainder.status

    Purchasing::CreateDemandCoveragePlans.call!(
      purchase_order: @purchase_order,
      actor: @user,
      line_plans: @line_plans
    )

    converted.reload
    assert_equal "converted", converted.status

    active = @purchase_order.purchase_order_line_demand_plans.active_plans
    assert_equal 1, active.count
    assert_equal "planned", active.first.status
    assert_not_equal converted.id, active.first.id
  end
end
