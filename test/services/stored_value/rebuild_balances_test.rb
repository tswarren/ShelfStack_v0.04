# frozen_string_literal: true

require "test_helper"

class StoredValue::RebuildBalancesTest < ActiveSupport::TestCase
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @user = create_user!
    @account = create_stored_value_account!(issuing_store: @store)
    StoredValue::Issue.call(
      account: @account, store: @store, actor: @user, amount_cents: 900, reason_code: stored_value_reason_code!
    )
  end

  test "rebuild fixes drifted cached balance" do
    @account.update_column(:current_balance_cents, 50)
    StoredValue::RebuildBalances.call(actor: @user)
    assert_equal 900, @account.reload.current_balance_cents
  end
end
