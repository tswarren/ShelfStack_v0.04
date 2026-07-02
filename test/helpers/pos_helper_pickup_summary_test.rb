# frozen_string_literal: true

require "test_helper"

class PosHelperPickupSummaryTest < ActionView::TestCase
  include PosHelper
  include Phase2TestHelper
  include Phase6TestHelper
  include Phase7aTestHelper
  include V0047TestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    seed_v0047_permissions!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_v0047_allocation_permissions!(@user, store: @store)
    grant_all_phase6_permissions!(@user, store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 2, line_number: 1 } ]
      ),
      user: @user
    )
    @customer = create_customer!(display_name: "Banner Pat")
    @demand_line = DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      capture_intent: "hold",
      quantity: 1,
      customer: @customer
    ).demand_line
    @allocation = @demand_line.demand_allocations.active_allocations.on_hand_kind.first
    @transaction = PosTransaction.create!(
      store: @store,
      workstation: @workstation,
      cashier_user: @user,
      status: "draft"
    )
    Pos::AddDemandAllocationLine.call!(
      transaction: @transaction,
      allocation: @allocation,
      added_by_user: @user
    )
  end

  test "pos_transaction_pickup_summary returns customer and demand number" do
    summary = pos_transaction_pickup_summary(@transaction)

    assert_equal "Banner Pat", summary.customer_name
    assert_includes summary.request_numbers, @demand_line.demand_number
    assert_equal 1, summary.line_count
  end

  test "pos_line_pickup_context returns structured pickup data" do
    line = @transaction.pos_transaction_lines.first
    context = pos_line_pickup_context(line)

    assert_equal "Banner Pat", context.customer_name
    assert_equal @demand_line.demand_number, context.request_number
  end
end
