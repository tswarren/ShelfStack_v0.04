# frozen_string_literal: true

require "test_helper"

class SourcingCloseRunTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include V0048TestHelper

  setup do
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @demand = create_special_order_demand!(store: @store, actor: @user, variant: @variant, quantity: 2)
    @run = Sourcing::StartRun.call!(demand_line: @demand, actor: @user)
  end

  test "close run requires reason when unresolved remains" do
    assert_raises(Sourcing::CloseRun::CloseRunError) do
      Sourcing::CloseRun.call!(sourcing_run: @run, actor: @user)
    end
  end

  test "close run with reason resolves run" do
    Sourcing::CloseRun.call!(sourcing_run: @run, actor: @user, close_reason: "Buyer stopped sourcing")

    assert_equal "resolved", @run.reload.status
    assert AuditEvent.exists?(event_name: "sourcing_run.closed", auditable: @run)
  end

  test "close run cancels pending attempts" do
    vendor = create_vendor_for_variant!(@variant)
    attempt = Sourcing::CreateAttempt.call!(
      sourcing_run: @run,
      actor: @user,
      vendor: vendor,
      quantity: 1
    )

    Sourcing::CloseRun.call!(sourcing_run: @run, actor: @user, close_reason: "Buyer stopped sourcing")

    assert_equal "canceled", attempt.reload.status
    assert_equal "resolved", @run.reload.status
  end
end
