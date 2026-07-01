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
    assert_no_difference -> { InventoryReservation.count } do
      assert_no_difference -> { InventoryLedgerEntry.count } do
        # counts already asserted via snapshot
      end
    end
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

  test "override allows over allocation with authorization" do
    grant_permission!(@user, "demand.allocations.override_availability", store: @store)

    allocation = DemandAllocations::AllocateOnHand.call!(
      demand_line: @demand_line,
      actor: @user,
      quantity: 4,
      override_availability: true,
      override_reason: "Customer priority",
      override_authorized_by_user: @user
    )

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert allocation.override_availability?
    assert_equal 4, balance.quantity_reserved
    assert_equal 1, balance.quantity_available
    assert AuditEvent.exists?(event_name: "demand_allocation.override_availability_used", auditable: allocation)
  end
end
