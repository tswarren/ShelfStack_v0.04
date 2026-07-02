# frozen_string_literal: true

require "test_helper"

class DemandLinesRecalculateAllocationStatusTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @demand_line = create_open_demand_line!(store: @store, actor: @user, variant: @variant, quantity: 2)
  end

  {
    [ 2, 0, 0 ] => "open",
    [ 2, 0, 1 ] => "partially_allocated",
    [ 2, 0, 2 ] => "allocated",
    [ 2, 1, 0 ] => "partially_allocated",
    [ 2, 1, 1 ] => "allocated",
    [ 2, 2, 0 ] => "fulfilled"
  }.each do |(requested, fulfilled, active), expected|
    test "requested #{requested} fulfilled #{fulfilled} active #{active} => #{expected}" do
      line = create_open_demand_line!(store: @store, actor: @user, variant: @variant, quantity: requested)
      create_allocation!(line, quantity: fulfilled, status: "fulfilled") if fulfilled.positive?
      create_allocation!(line, quantity: active, status: "active") if active.positive?

      DemandLines::RecalculateAllocationStatus.call!(demand_line: line, actor: @user)

      assert_equal expected, line.reload.status
    end
  end

  private

  def create_allocation!(line, quantity:, status:)
    DemandAllocation.create!(
      store: @store,
      demand_line: line,
      product: line.product,
      product_variant: line.product_variant,
      allocation_kind: "on_hand",
      status: status,
      quantity_allocated: quantity,
      allocated_by_user: @user,
      allocated_at: Time.current,
      fulfilled_by_user: (status == "fulfilled" ? @user : nil),
      fulfilled_at: (status == "fulfilled" ? Time.current : nil)
    )
  end
end
