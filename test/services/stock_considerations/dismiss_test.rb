# frozen_string_literal: true

require "test_helper"

class StockConsiderationsDismissTest < ActiveSupport::TestCase
  include Phase3TestHelper

  setup do
    Seeds::V0046Permissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @consideration = StockConsiderations::Create.call!(
      store: @store,
      actor: @user,
      variant: @variant,
      reason: "Maybe later"
    )
    @ledger_before = InventoryLedgerEntry.count
  end

  test "dismisses with reason and audit" do
    StockConsiderations::Dismiss.call!(
      consideration: @consideration,
      actor: @user,
      dismiss_reason: "Already on order",
      status: "dismissed"
    )

    @consideration.reload
    assert_equal "dismissed", @consideration.status
    assert_equal "Already on order", @consideration.dismiss_reason
    assert_equal @user, @consideration.dismissed_by_user
    assert @consideration.dismissed_at.present?
    assert AuditEvent.exists?(event_name: "stock_consideration.dismissed", auditable: @consideration)
    assert_equal @ledger_before, InventoryLedgerEntry.count
  end

  test "supports duplicate and already_carried statuses" do
    %w[duplicate already_carried].each do |status|
      consideration = StockConsiderations::Create.call!(
        store: @store,
        actor: @user,
        variant: @variant,
        reason: status
      )

      StockConsiderations::Dismiss.call!(
        consideration: consideration,
        actor: @user,
        status: status
      )

      assert_equal status, consideration.reload.status
    end
  end

  test "dismiss does not create demand rows" do
    assert_no_difference -> { DemandLine.count } do
      StockConsiderations::Dismiss.call!(
        consideration: @consideration,
        actor: @user,
        dismiss_reason: "Not needed"
      )
    end
  end
end
