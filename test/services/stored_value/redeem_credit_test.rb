# frozen_string_literal: true

require "test_helper"

class StoredValue::RedeemCreditTest < ActiveSupport::TestCase
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @user = create_user!
    @account = create_stored_value_account!(issuing_store: @store)
    StoredValue::Issue.call(
      account: @account,
      store: @store,
      actor: @user,
      amount_cents: 1000,
      reason_code: stored_value_reason_code!
    )
    @account.reload
  end

  test "redeem decreases balance" do
    StoredValue::RedeemCredit.call(
      account: @account,
      store: @store,
      actor: @user,
      amount_cents: 400
    )

    @account.reload
    assert_equal 600, @account.current_balance_cents
  end

  test "second redeem fails when balance insufficient" do
    StoredValue::RedeemCredit.call(
      account: @account,
      store: @store,
      actor: @user,
      amount_cents: 700
    )

    assert_raises(StoredValue::Post::Error) do
      StoredValue::RedeemCredit.call(
        account: @account,
        store: @store,
        actor: @user,
        amount_cents: 700
      )
    end

    assert_equal 300, @account.reload.current_balance_cents
  end

  test "inactive account blocks redeem" do
    @account.suspend!
    assert_raises(StoredValue::Post::Error) do
      StoredValue::RedeemCredit.call(
        account: @account,
        store: @store,
        actor: @user,
        amount_cents: 100
      )
    end
  end
end
