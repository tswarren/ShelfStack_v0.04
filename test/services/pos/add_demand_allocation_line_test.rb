# frozen_string_literal: true

require "test_helper"

class PosAddDemandAllocationLineTest < ActiveSupport::TestCase
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
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 3)
    @demand_line = DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      capture_intent: "hold",
      quantity: 2,
      customer: create_customer!
    ).demand_line
    @allocation = @demand_line.demand_allocations.active_allocations.on_hand_kind.first
    @transaction = PosTransaction.create!(
      store: @store,
      workstation: @workstation,
      cashier_user: @user,
      status: "draft"
    )
  end

  test "creates pickup line linked to demand allocation and customer" do
    line = Pos::AddDemandAllocationLine.call!(
      transaction: @transaction,
      allocation: @allocation,
      added_by_user: @user
    )

    assert_equal @allocation.id, line.demand_allocation_id
    assert_equal 2, line.quantity
    assert_equal @demand_line.customer_id, @transaction.reload.customer_id
  end

  test "rejects quantity mismatch" do
    assert_raises(Pos::AddDemandAllocationLine::Error) do
      Pos::AddDemandAllocationLine.call!(
        transaction: @transaction,
        allocation: @allocation,
        added_by_user: @user,
        quantity: 1
      )
    end
  end

  test "same demand allocation cannot be added to two draft transactions" do
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

    assert_raises(Pos::AddDemandAllocationLine::Error, match: /another open transaction/) do
      Pos::AddDemandAllocationLine.call!(
        transaction: other_transaction,
        allocation: @allocation,
        added_by_user: @user
      )
    end
  end

  test "void removing line before completion leaves allocation active and reusable" do
    line = Pos::AddDemandAllocationLine.call!(
      transaction: @transaction,
      allocation: @allocation,
      added_by_user: @user
    )

    line.destroy!

    other_transaction = PosTransaction.create!(
      store: @store,
      workstation: @workstation,
      cashier_user: @user,
      status: "draft"
    )

    assert_equal "active", @allocation.reload.status

    reused_line = Pos::AddDemandAllocationLine.call!(
      transaction: other_transaction,
      allocation: @allocation,
      added_by_user: @user
    )

    assert_equal @allocation.id, reused_line.demand_allocation_id
  end
end
