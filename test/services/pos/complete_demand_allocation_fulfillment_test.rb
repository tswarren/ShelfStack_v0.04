# frozen_string_literal: true

require "test_helper"

class PosCompleteDemandAllocationFulfillmentTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase4TestHelper
  include Phase6TestHelper
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_v0047_allocation_permissions!(@user, store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 3)
    @demand_line = DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      capture_intent: "hold",
      quantity: 1,
      customer: create_customer!
    ).demand_line
    @allocation = @demand_line.demand_allocations.active_allocations.on_hand_kind.first
    @transaction = PosTransaction.create!(
      store: @store,
      workstation: @workstation,
      cashier_user: @user,
      status: "completed"
    )
    @line = @transaction.pos_transaction_lines.create!(
      line_number: 1,
      line_type: "variant",
      product_variant: @variant,
      quantity: 1,
      unit_price_cents: @variant.selling_price_cents,
      demand_allocation: @allocation
    )
  end

  test "fulfills active demand allocations linked to transaction lines" do
    Pos::CompleteDemandAllocationFulfillment.call!(
      transaction: @transaction,
      fulfilled_by_user: @user
    )

    @allocation.reload
    assert_equal "fulfilled", @allocation.status
    assert_equal "PosTransactionLine", @allocation.fulfillment_reference_type
    assert_equal @line.id, @allocation.fulfillment_reference_id
  end

  test "skips lines without demand allocation" do
    draft_transaction = PosTransaction.create!(
      store: @store,
      workstation: @workstation,
      cashier_user: @user,
      status: "draft"
    )
    draft_transaction.pos_transaction_lines.create!(
      line_number: 1,
      line_type: "variant",
      product_variant: @variant,
      quantity: 1,
      unit_price_cents: @variant.selling_price_cents
    )

    assert_nothing_raised do
      Pos::CompleteDemandAllocationFulfillment.call!(
        transaction: draft_transaction,
        fulfilled_by_user: @user
      )
    end

    assert_equal "active", @allocation.reload.status
  end

  test "completion fails if linked demand allocation is no longer active" do
    DemandAllocations::Fulfill.call!(
      allocation: @allocation,
      actor: @user,
      fulfillment_reference: @line
    )

    assert_raises(Pos::CompleteDemandAllocationFulfillment::Error, match: /no longer active/) do
      Pos::CompleteDemandAllocationFulfillment.call!(
        transaction: @transaction,
        fulfilled_by_user: @user
      )
    end
  end
end
