# frozen_string_literal: true

require "test_helper"

class StockConsiderationsCreateTest < ActiveSupport::TestCase
  include Phase3TestHelper

  setup do
    Seeds::V0046Permissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "creates open consideration with audit" do
    consideration = StockConsiderations::Create.call!(
      store: @store,
      actor: @user,
      variant: @variant,
      reason: "Low stock on shelf",
      quantity_suggested: 3
    )

    assert_equal "open", consideration.status
    assert_equal @variant, consideration.product_variant
    assert AuditEvent.exists?(event_name: "stock_consideration.created", auditable: consideration)
  end

  test "create does not change inventory or legacy demand" do
    ledger_before = InventoryLedgerEntry.count

    assert_no_difference [ -> { CustomerRequest.count }, -> { DemandLine.count } ] do
      StockConsiderations::Create.call!(
        store: @store,
        actor: @user,
        provisional_title: "Possible restock title"
      )
    end

    assert_equal ledger_before, InventoryLedgerEntry.count
  end
end
