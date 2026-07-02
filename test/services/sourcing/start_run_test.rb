# frozen_string_literal: true

require "test_helper"

class SourcingStartRunTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include V0048TestHelper

  setup do
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @demand = create_special_order_demand!(store: @store, actor: @user, variant: @variant, quantity: 2)
    @ledger_before = InventoryLedgerEntry.count
  end

  test "creates sourcing run with audit and no inventory post" do
    run = Sourcing::StartRun.call!(demand_line: @demand, actor: @user)

    assert_equal "open", run.status
    assert_equal 2, run.quantity_requested
    assert AuditEvent.exists?(event_name: "sourcing_run.created", auditable: run)
    assert_equal @ledger_before, InventoryLedgerEntry.count
  end

  test "rejects quantity above unresolved" do
    error = assert_raises(Sourcing::StartRun::StartRunError) do
      Sourcing::StartRun.call!(demand_line: @demand, actor: @user, quantity: 5)
    end

    assert_match(/unresolved/i, error.message)
  end

  test "rejects second active run" do
    Sourcing::StartRun.call!(demand_line: @demand, actor: @user)

    assert_raises(Sourcing::StartRun::StartRunError) do
      Sourcing::StartRun.call!(demand_line: @demand.reload, actor: @user)
    end
  end
end
