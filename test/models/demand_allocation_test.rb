# frozen_string_literal: true

require "test_helper"

class DemandAllocationTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase4TestHelper
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @customer = create_customer!(display_name: "Allocation Customer")
    @demand_line = create_open_demand_line!(store: @store, actor: @user, variant: @variant, customer: @customer)
  end

  test "valid on_hand allocation" do
    allocation = DemandAllocation.new(
      store: @store,
      demand_line: @demand_line,
      product: @variant.product,
      product_variant: @variant,
      allocation_kind: "on_hand",
      status: "active",
      quantity_allocated: 1,
      allocated_by_user: @user,
      allocated_at: Time.current
    )

    assert allocation.valid?
  end

  test "inbound allocation requires purchase order line" do
    allocation = DemandAllocation.new(
      store: @store,
      demand_line: @demand_line,
      product: @variant.product,
      product_variant: @variant,
      allocation_kind: "inbound_purchase_order",
      status: "active",
      quantity_allocated: 1,
      allocated_by_user: @user,
      allocated_at: Time.current
    )

    assert_not allocation.valid?
    assert_includes allocation.errors[:purchase_order_line], "is required for inbound allocation"
  end

  test "override requires authorization fields for on_hand" do
    allocation = DemandAllocation.new(
      store: @store,
      demand_line: @demand_line,
      product: @variant.product,
      product_variant: @variant,
      allocation_kind: "on_hand",
      status: "active",
      quantity_allocated: 1,
      allocated_by_user: @user,
      allocated_at: Time.current,
      override_availability: true
    )

    assert_not allocation.valid?
    assert_includes allocation.errors[:override_authorized_by_user], "is required when overriding availability"
  end
end
