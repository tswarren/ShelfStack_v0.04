# frozen_string_literal: true

require "test_helper"

class Pos::SuspendedTransactionsLookupTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @other_workstation = create_workstation!(store: @store, attrs: { workstation_number: "002", workstation_code: "001-REG002", name: "Back Register" })
    @cashier = create_user!(username: "held_lookup_cashier")
    @variant = create_product_variant!
  end

  test "returns suspended transactions for store and workstation ordered newest first" do
    older = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: { status: "suspended", suspended_at: 2.hours.ago },
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 } ]
    )
    newer = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: { status: "suspended", suspended_at: 30.minutes.ago },
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1200, extended_price_cents: 1200 } ]
    )
    create_pos_transaction!(
      store: @store,
      workstation: @other_workstation,
      user: @cashier,
      attrs: { status: "suspended", suspended_at: Time.current },
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 900, extended_price_cents: 900 } ]
    )
    create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 800, extended_price_cents: 800 } ]
    )

    results = Pos::SuspendedTransactionsLookup.for_workstation(store: @store, workstation: @workstation)

    assert_equal [ newer.id, older.id ], results.map(&:id)
  end
end
