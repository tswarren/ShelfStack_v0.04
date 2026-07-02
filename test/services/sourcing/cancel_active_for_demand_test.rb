# frozen_string_literal: true

require "test_helper"

class SourcingCancelActiveForDemandTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include V0048TestHelper

  setup do
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @vendor = create_vendor_for_variant!(@variant)
    @demand = create_special_order_demand!(store: @store, actor: @user, variant: @variant, quantity: 2)
    @run = Sourcing::StartRun.call!(demand_line: @demand, actor: @user)
    @attempt = Sourcing::CreateAttempt.call!(sourcing_run: @run, actor: @user, vendor: @vendor, quantity: 2)
    Sourcing::SubmitAttempt.call!(sourcing_attempt: @attempt, actor: @user)
  end

  test "demand cancel cancels active sourcing run and attempts" do
    DemandLines::Cancel.call!(demand_line: @demand, actor: @user, cancel_reason: "Customer canceled")

    assert_equal "canceled", @run.reload.status
    assert_equal "canceled", @attempt.reload.status
    assert_equal "canceled", @demand.reload.status
  end

  test "demand expire cancels active sourcing" do
    DemandLines::Expire.call!(demand_line: @demand, actor: @user)

    assert_equal "canceled", @run.reload.status
    assert_equal "expired", @demand.reload.status
  end
end
