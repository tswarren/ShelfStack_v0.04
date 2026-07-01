# frozen_string_literal: true

require "test_helper"

class DemandAllocationsAllocateOnHandTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase4TestHelper
  include Phase5TestHelper
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 5)
    @demand_line = create_open_demand_line!(store: @store, actor: @user, variant: @variant, quantity: 2)
    @before = inventory_snapshot(store: @store, variant: @variant)
  end

  test "allocates on hand and updates cache without inventory post" do
    allocation = DemandAllocations::AllocateOnHand.call!(
      demand_line: @demand_line,
      actor: @user,
      quantity: 2
    )

    after = inventory_snapshot(store: @store, variant: @variant)
    assert_inventory_unchanged_except_cache(before: @before, after: after)
    assert_equal 2, after[:reserved]
    assert_equal 3, after[:available]
    assert_equal "active", allocation.status
    assert_equal "allocated", @demand_line.reload.status
    assert AuditEvent.exists?(event_name: "demand_allocation.created", auditable: allocation)
  end

  test "rejects allocation beyond available without override" do
    assert_raises(DemandAllocations::AllocateOnHand::AllocateError) do
      DemandAllocations::AllocateOnHand.call!(
        demand_line: @demand_line,
        actor: @user,
        quantity: 10
      )
    end
  end

  test "rejects allocation beyond unallocated demand quantity" do
    assert_raises(DemandAllocations::AllocateOnHand::AllocateError) do
      DemandAllocations::AllocateOnHand.call!(
        demand_line: @demand_line,
        actor: @user,
        quantity: 3
      )
    end
  end

  test "rejects second allocation when demand is fully allocated" do
    DemandAllocations::AllocateOnHand.call!(demand_line: @demand_line, actor: @user, quantity: 2)

    assert_raises(DemandAllocations::AllocateOnHand::AllocateError) do
      DemandAllocations::AllocateOnHand.call!(
        demand_line: @demand_line,
        actor: @user,
        quantity: 1
      )
    end
  end

  test "rejects allocation beyond remaining after partial fulfill" do
    allocation = DemandAllocations::AllocateOnHand.call!(demand_line: @demand_line, actor: @user, quantity: 1)
    DemandAllocations::Fulfill.call!(allocation: allocation, actor: @user)

    assert_raises(DemandAllocations::AllocateOnHand::AllocateError) do
      DemandAllocations::AllocateOnHand.call!(
        demand_line: @demand_line.reload,
        actor: @user,
        quantity: 2
      )
    end

    remaining_allocation = DemandAllocations::AllocateOnHand.call!(
      demand_line: @demand_line.reload,
      actor: @user,
      quantity: 1
    )
    assert_equal 1, remaining_allocation.quantity_allocated
  end

  test "override allows stock overage but not demand overage" do
    grant_permission!(@user, "demand.allocations.override_availability", store: @store)
    InventoryBalance.find_by!(store: @store, product_variant: @variant).update!(
      quantity_on_hand: 1,
      quantity_reserved: 0,
      quantity_available: 1
    )

    allocation = DemandAllocations::AllocateOnHand.call!(
      demand_line: @demand_line,
      actor: @user,
      quantity: 2,
      override_availability: true,
      override_reason: "Customer priority",
      override_authorized_by_user: @user
    )

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert allocation.override_availability?
    assert_equal 2, balance.quantity_reserved
    assert_equal(-1, balance.quantity_available)

    assert_raises(DemandAllocations::AllocateOnHand::AllocateError) do
      DemandAllocations::AllocateOnHand.call!(
        demand_line: @demand_line.reload,
        actor: @user,
        quantity: 1,
        override_availability: true,
        override_reason: "Should fail",
        override_authorized_by_user: @user
      )
    end
  end
end
