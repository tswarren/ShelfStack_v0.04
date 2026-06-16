# frozen_string_literal: true

require "test_helper"

class Inventory::BalanceUpdaterTest < ActiveSupport::TestCase
  setup do
    seed_phase4_reference_data!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    Current.store = @store
  end

  test "records negative audit when crossing below zero" do
    post_positive!(5)
    post_negative!(-8)

    assert AuditEvent.exists?(event_name: "inventory_balance.negative")
  end

  test "records cleared negative when returning to zero or positive" do
    post_positive!(5)
    post_negative!(-8)
    post_positive!(10)

    assert AuditEvent.exists?(event_name: "inventory_balance.cleared_negative")
  end

  private

  def post_positive!(delta)
    adjustment = create_inventory_adjustment!(
      store: @store,
      lines: [ { product_variant: @variant, quantity_delta: delta, line_number: 1 } ]
    )
    Inventory::PostAdjustment.call(adjustment: adjustment, posted_by_user: @user)
  end

  def post_negative!(delta)
    adjustment = create_inventory_adjustment!(
      store: @store,
      lines: [ { product_variant: @variant, quantity_delta: delta, line_number: 1 } ]
    )
    Inventory::PostAdjustment.call(adjustment: adjustment, posted_by_user: @user)
  end
end
