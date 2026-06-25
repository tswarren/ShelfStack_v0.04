# frozen_string_literal: true

require "test_helper"

class Inventory::SourceHintTest < ActiveSupport::TestCase
  setup do
    seed_phase4_reference_data!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    Current.store = @store
  end

  test "uses most recent acquisition movement" do
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 2)

    hint = Inventory::SourceHint.for(variant: @variant, store: @store)

    assert_equal "Supplier", hint.label
    assert_equal "received", hint.movement_type
    assert_not hint.authoritative
  end

  test "ignores sold movement when receipt exists earlier" do
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 5)
    post_sold_movement!

    hint = Inventory::SourceHint.for(variant: @variant, store: @store)

    assert_equal "Supplier", hint.label
  end

  test "buyback-eligible condition with no history suggests trade-in" do
    used = ProductCondition.active_records.find_by(new_condition: false, buyback_eligible: true) ||
           create_product_condition!(
             condition_key: "used_hint_#{SecureRandom.hex(3)}",
             short_name: "Used #{SecureRandom.hex(2)}",
             new_condition: false,
             buyback_eligible: true
           )
    @variant.update!(condition: used)

    hint = Inventory::SourceHint.for(variant: @variant, store: @store)

    assert_equal "Usually trade-in", hint.label
  end

  test "no history returns not yet stocked" do
    hint = Inventory::SourceHint.for(variant: @variant, store: @store)

    assert_equal "Not yet stocked", hint.label
  end

  private

  def post_sold_movement!
    source = create_pos_transaction!(
      store: @store,
      workstation: create_workstation!(store: @store),
      user: @user,
      attrs: { status: "completed", transaction_type: "sale" },
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 } ]
    )

    Inventory::Post.call(
      store: @store,
      posted_by_user: @user,
      posting_type: "pos_transaction",
      source: source,
      idempotency_key: "test-sold-#{SecureRandom.hex(4)}",
      lines: [
        Inventory::Post::LinePayload.new(
          product_variant: @variant,
          quantity_delta: -1,
          movement_type: "sold",
          manual_unit_cost_cents: nil,
          cost_source: nil,
          inventory_location: nil,
          inventory_reason_code: nil
        )
      ]
    )
  end
end
