# frozen_string_literal: true

require "test_helper"

class SourcingRunTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include V0048TestHelper

  setup do
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @demand = create_special_order_demand!(store: @store, actor: @user, variant: @variant, quantity: 2)
  end

  test "valid sourcing run" do
    run = SourcingRun.new(
      store: @store,
      demand_line: @demand,
      product: @demand.product,
      product_variant: @variant,
      status: "open",
      quantity_requested: 2,
      started_by_user: @user,
      started_at: Time.current
    )

    assert run.valid?
  end

  test "rejects second active run for same demand line" do
    SourcingRun.create!(
      store: @store,
      demand_line: @demand,
      product: @demand.product,
      product_variant: @variant,
      status: "open",
      quantity_requested: 1,
      started_by_user: @user,
      started_at: Time.current
    )

    duplicate = SourcingRun.new(
      store: @store,
      demand_line: @demand,
      product: @demand.product,
      product_variant: @variant,
      status: "open",
      quantity_requested: 1,
      started_by_user: @user,
      started_at: Time.current
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:demand_line], "already has an active sourcing run"
  end
end
