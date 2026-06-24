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

  test "buyback_offer inbound updates moving average cost" do
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 2, unit_cost_cents: 1000)
    apply_inbound!(quantity: 1, unit_cost_cents: 400, cost_source: "buyback_offer")

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 3, balance.quantity_on_hand
    assert_equal 800, balance.moving_average_unit_cost_cents
  end

  private

  def apply_inbound!(quantity:, unit_cost_cents:, cost_source:)
    valuation = Inventory::CostEstimator.estimate(
      variant: @variant,
      quantity_delta: quantity,
      manual_unit_cost_cents: unit_cost_cents,
      cost_source: cost_source
    )
    posting = InventoryPosting.create!(
      posting_type: "used_buyback",
      source: create_inventory_adjustment!(store: @store, lines: [ { product_variant: @variant, quantity_delta: quantity, line_number: 1 } ]),
      store: @store,
      posted_at: Time.current,
      posted_by_user: @user,
      idempotency_key: "test-mac-#{SecureRandom.hex(4)}"
    )
    Inventory::BalanceUpdater.apply!(
      store: @store,
      variant: @variant,
      quantity_delta: quantity,
      valuation: valuation,
      posting: posting
    )
  end

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
