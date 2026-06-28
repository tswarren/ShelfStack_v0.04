# frozen_string_literal: true

require "test_helper"

class Pos::StoredValueTenderSupportTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @account = create_stored_value_account!(issuing_store: @store, current_balance_cents: 2500)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: create_workstation!(store: @store),
      user: create_user!,
      attrs: { total_cents: 4000 }
    )
  end

  test "caps redeem amount to account balance" do
    amount = Pos::StoredValueTenderSupport.capped_redeem_amount_cents(
      transaction: @transaction,
      tender_type: "store_credit",
      amount_cents: 4000,
      account: @account
    )

    assert_equal 2500, amount
  end

  test "caps gift card redeem amount to account balance" do
    gift_card_account = create_stored_value_account!(
      issuing_store: @store,
      account_type: "gift_card",
      current_balance_cents: 1800
    )

    amount = Pos::StoredValueTenderSupport.capped_redeem_amount_cents(
      transaction: @transaction,
      tender_type: "gift_card",
      amount_cents: 4000,
      account: gift_card_account
    )

    assert_equal 1800, amount
  end

  test "leaves entered amount when below balance" do
    amount = Pos::StoredValueTenderSupport.capped_redeem_amount_cents(
      transaction: @transaction,
      tender_type: "store_credit",
      amount_cents: 1500,
      account: @account
    )

    assert_equal 1500, amount
  end

  test "does not cap refund issue amounts" do
    @transaction.update!(total_cents: -1500)

    amount = Pos::StoredValueTenderSupport.capped_redeem_amount_cents(
      transaction: @transaction,
      tender_type: "store_credit",
      amount_cents: -1500,
      account: @account
    )

    assert_equal(-1500, amount)
  end

  test "resolve_tender_type_for_account maps gift card and store credit accounts" do
    gift_card_account = create_stored_value_account!(
      issuing_store: @store,
      account_type: "gift_card",
      current_balance_cents: 1000
    )

    assert_equal "gift_card", Pos::StoredValueTenderSupport.resolve_tender_type_for_account(gift_card_account)
    assert_equal "store_credit", Pos::StoredValueTenderSupport.resolve_tender_type_for_account(@account)
  end

  test "stored_value placeholder is distinct from persisted stored value tender types" do
    assert Pos::StoredValueTenderSupport.stored_value_placeholder?("stored_value")
    refute Pos::StoredValueTenderSupport.stored_value_tender?("stored_value")
    assert Pos::StoredValueTenderSupport.stored_value_tender?("gift_card")
  end
end
