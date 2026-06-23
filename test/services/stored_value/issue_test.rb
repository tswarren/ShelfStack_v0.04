# frozen_string_literal: true

require "test_helper"

class StoredValue::IssueTest < ActiveSupport::TestCase
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @user = create_user!
    @account = create_stored_value_account!(issuing_store: @store)
    @reason = stored_value_reason_code!
    Current.store = @store
  end

  test "issue increases balance and creates ledger entry" do
    entry = StoredValue::Issue.call(
      account: @account,
      store: @store,
      actor: @user,
      amount_cents: 1500,
      reason_code: @reason
    )

    @account.reload
    assert_equal 1500, @account.current_balance_cents
    assert_equal "issue", entry.entry_type
    assert AuditEvent.exists?(event_name: "stored_value.ledger.issued")
  end
end
