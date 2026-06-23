# frozen_string_literal: true

require "test_helper"

class StoredValue::BalanceIntegrityCheckTest < ActiveSupport::TestCase
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @user = create_user!
    @account = create_stored_value_account!(issuing_store: @store)
    StoredValue::Issue.call(
      account: @account, store: @store, actor: @user, amount_cents: 500, reason_code: stored_value_reason_code!
    )
  end

  test "passes when cache matches ledger" do
    result = StoredValue::BalanceIntegrityCheck.call(actor: @user)
    assert result.passed
  end

  test "detects mismatch" do
    @account.update_column(:current_balance_cents, 999)
    result = StoredValue::BalanceIntegrityCheck.call(actor: @user)
    assert_not result.passed
  end
end
