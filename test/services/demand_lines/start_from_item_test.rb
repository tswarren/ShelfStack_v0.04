# frozen_string_literal: true

require "test_helper"

class DemandLinesStartFromItemTest < ActiveSupport::TestCase
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
    @customer = create_customer!(display_name: "Item Customer")
  end

  test "start from item creates demand line only for notify" do
    assert_difference -> { DemandLine.count }, 1 do
      result = DemandLines::StartFromItem.call!(
        store: @store,
        variant: @variant,
        actor: @user,
        capture_intent: "notify",
        customer: @customer
      )
      assert_nil result.allocation_result
    end
  end

  test "hold with no stock stays open without allocation" do
    result = DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      capture_intent: "hold",
      customer: @customer,
      quantity: 3
    )

    assert_equal :none, result.allocation_result
    assert_equal "open", result.demand_line.status
    assert_equal 0, result.demand_line.demand_allocations.count
  end

  test "hold partial auto allocates available quantity" do
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 2)

    result = DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      capture_intent: "hold",
      customer: @customer,
      quantity: 3
    )

    assert_equal :partial, result.allocation_result
    assert_equal "partially_allocated", result.demand_line.status
    assert_equal 2, result.demand_line.demand_allocations.active_allocations.sum(:quantity_allocated)
  end

  test "hold full auto allocates when stock covers request" do
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 3)

    result = DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      capture_intent: "hold",
      customer: @customer,
      quantity: 2
    )

    assert_equal :full, result.allocation_result
    assert_equal "allocated", result.demand_line.status
  end

  test "hold defaults expires_at to about 14 days" do
    travel_to Time.zone.parse("2026-07-01 12:00") do
      result = DemandLines::StartFromItem.call!(
        store: @store,
        variant: @variant,
        actor: @user,
        capture_intent: "hold",
        customer: @customer
      )

      assert_in_delta 14.days.from_now, result.demand_line.expires_at, 1.minute
    end
  end

  test "hold returns none when allocation loses stock race" do
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 1)

    original = DemandAllocations::AllocateOnHand.method(:call!)
    DemandAllocations::AllocateOnHand.singleton_class.define_method(:call!) do |**|
      raise DemandAllocations::AllocateOnHand::AllocateError, "Insufficient available quantity (0)"
    end

    result = DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      capture_intent: "hold",
      customer: @customer,
      quantity: 1
    )

    assert_equal :none, result.allocation_result
    assert_equal "open", result.demand_line.status
    assert_equal 0, result.demand_line.demand_allocations.count
  ensure
    DemandAllocations::AllocateOnHand.singleton_class.define_method(:call!, original)
  end
end
