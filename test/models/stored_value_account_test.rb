# frozen_string_literal: true

require "test_helper"

class StoredValueAccountTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
  end

  test "validates account type" do
    account = StoredValueAccount.new(issuing_store: @store, account_type: "invalid")
    assert_not account.valid?
  end

  test "close requires zero balance" do
    account = create_stored_value_account!(issuing_store: @store, current_balance_cents: 500)
    assert_raises(ActiveRecord::RecordInvalid) { account.close! }
  end

  test "close succeeds with zero balance" do
    account = create_stored_value_account!(issuing_store: @store)
    account.close!
    assert_not account.active?
  end

  test "reactivate restores active status" do
    account = create_stored_value_account!(issuing_store: @store)
    account.suspend!
    account.reactivate!
    assert account.active?
  end
end
