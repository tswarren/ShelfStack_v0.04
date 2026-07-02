# frozen_string_literal: true

require "test_helper"

class StockConsiderationsConvertToDemandTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase4TestHelper

  setup do
    Seeds::V0046Permissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @consideration = StockConsiderations::Create.call!(
      store: @store,
      actor: @user,
      variant: @variant,
      quantity_suggested: 2,
      notes: "Convert me"
    )
    @ledger_before = InventoryLedgerEntry.count
  end

  test "converts to demand line with provenance and audit" do
    demand_line = StockConsiderations::ConvertToDemand.call!(
      consideration: @consideration,
      actor: @user
    )

    @consideration.reload
    assert_equal "converted_to_demand", @consideration.status
    assert_equal @user, @consideration.converted_by_user
    assert @consideration.converted_at.present?
    assert_equal @user, @consideration.reviewed_by_user
    assert @consideration.reviewed_at.present?
    assert_equal @consideration, demand_line.stock_consideration
    assert_equal "buyer_replenishment", demand_line.capture_intent
    assert AuditEvent.exists?(event_name: "stock_consideration.converted", auditable: @consideration)
    assert_equal @ledger_before, InventoryLedgerEntry.count
  end

  test "convert does not create duplicate demand rows" do
    assert_difference -> { DemandLine.count }, 1 do
      StockConsiderations::ConvertToDemand.call!(consideration: @consideration, actor: @user)
    end
  end

  test "cannot convert twice" do
    StockConsiderations::ConvertToDemand.call!(consideration: @consideration, actor: @user)

    assert_raises StockConsiderations::ConvertToDemand::ConvertError do
      StockConsiderations::ConvertToDemand.call!(consideration: @consideration.reload, actor: @user)
    end
  end
end
