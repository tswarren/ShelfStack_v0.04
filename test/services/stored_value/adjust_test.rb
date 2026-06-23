# frozen_string_literal: true

require "test_helper"

class StoredValue::AdjustTest < ActiveSupport::TestCase
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @user = create_user!
    @account = create_stored_value_account!(issuing_store: @store)
    @reason = stored_value_reason_code!
    StoredValue::Issue.call(
      account: @account, store: @store, actor: @user, amount_cents: 1000, reason_code: @reason
    )
    @account.reload
  end

  test "negative adjust cannot go below zero" do
    assert_raises(StoredValue::Post::Error) do
      StoredValue::Adjust.call(
        account: @account,
        store: @store,
        actor: @user,
        amount_delta_cents: -2000,
        reason_code: stored_value_reason_code!("manual_adjustment")
      )
    end
  end
end
