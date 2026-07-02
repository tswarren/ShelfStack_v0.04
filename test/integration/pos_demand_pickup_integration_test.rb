# frozen_string_literal: true

require "test_helper"

class PosDemandPickupIntegrationTest < ActiveSupport::TestCase
  include Phase2TestHelper
  include Phase6TestHelper
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_v0047_allocation_permissions!(@user, store: @store)
    grant_all_phase6_permissions!(@user, store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 5)
    @demand_line = DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      capture_intent: "hold",
      quantity: 1,
      customer: create_customer!
    ).demand_line
    @allocation = @demand_line.demand_allocations.active_allocations.on_hand_kind.first
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    @transaction = PosTransaction.create!(
      store: @store,
      workstation: @workstation,
      cashier_user: @user,
      status: "draft"
    )
  end

  test "on-hand demand pickup completes and fulfills allocation" do
    Pos::AddDemandAllocationLine.call!(
      transaction: @transaction,
      allocation: @allocation,
      added_by_user: @user
    )

    complete_pos_sale!(transaction: @transaction, user: @user, register_session: @register_session)

    @allocation.reload
    @demand_line.reload
    assert_equal "fulfilled", @allocation.status
    assert_equal "fulfilled", @demand_line.status
    assert_equal "PosTransactionLine", @allocation.fulfillment_reference_type
  end

  test "void before completion leaves allocation active" do
    line = Pos::AddDemandAllocationLine.call!(
      transaction: @transaction,
      allocation: @allocation,
      added_by_user: @user
    )

    line.destroy!
    @transaction.reload

    assert_equal "active", @allocation.reload.status
    assert_equal "allocated", @demand_line.reload.status
  end

  test "same demand allocation cannot complete on two transactions" do
    other_transaction = PosTransaction.create!(
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

    assert_raises(Pos::AddDemandAllocationLine::Error) do
      Pos::AddDemandAllocationLine.call!(
        transaction: other_transaction,
        allocation: @allocation,
        added_by_user: @user
      )
    end
  end
end
