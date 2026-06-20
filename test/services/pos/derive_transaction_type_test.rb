# frozen_string_literal: true

require "test_helper"

class Pos::DeriveTransactionTypeTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!
  end

  test "all positive lines are sale" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 } ]
    )
    assert_equal "sale", Pos::DeriveTransactionType.call(transaction)
  end

  test "mixed signs are exchange" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 },
        { product_variant: @variant, quantity: -1, unit_price_cents: 1000, extended_price_cents: -1000, return_disposition: "return_to_stock" }
      ]
    )
    assert_equal "exchange", Pos::DeriveTransactionType.call(transaction)
  end
end
