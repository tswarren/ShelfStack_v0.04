# frozen_string_literal: true

require "test_helper"

class DemandLines::SurfaceNotifyLinesTest < ActiveSupport::TestCase
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    grant_v0047_allocation_permissions!(@user, store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 2)
    @demand_line = DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      capture_intent: "notify",
      quantity: 1,
      customer: create_customer!
    ).demand_line
  end

  test "recalculates notify demand lines when stock is available" do
    assert_nothing_raised do
      DemandLines::SurfaceNotifyLines.for_variant(store: @store, variant: @variant, actor: @user)
    end

    assert_equal "open", @demand_line.reload.status
  end

  test "no-op when variant has no available stock" do
    InventoryBalance.find_by!(store: @store, product_variant: @variant).update!(
      quantity_on_hand: 0,
      quantity_available: 0,
      quantity_reserved: 0
    )

    assert_nothing_raised do
      DemandLines::SurfaceNotifyLines.for_variant(store: @store, variant: @variant, actor: @user)
    end
  end
end
