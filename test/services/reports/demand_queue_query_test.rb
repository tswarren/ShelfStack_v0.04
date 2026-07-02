# frozen_string_literal: true

require "test_helper"

class ReportsDemandQueueQueryTest < ActiveSupport::TestCase
  include Phase4TestHelper
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
      capture_intent: "hold",
      quantity: 1,
      customer: create_customer!
    ).demand_line
  end

  test "ready_for_pickup queue returns matching demand rows" do
    result = Reports::DemandQueue::Query.call(store: @store, queue: "ready_for_pickup")

    assert_not result.empty?
    assert_equal @demand_line.demand_number, result.rows.first.label
  end
end
