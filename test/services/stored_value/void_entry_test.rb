# frozen_string_literal: true

require "test_helper"

class StoredValue::VoidEntryTest < ActiveSupport::TestCase
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @user = create_user!
    @account = create_stored_value_account!(issuing_store: @store)
    @reason = stored_value_reason_code!
    @entry = StoredValue::Issue.call(
      account: @account, store: @store, actor: @user, amount_cents: 800, reason_code: @reason
    )
    @account.reload
  end

  test "void creates reversing entry without mutating original" do
    original_delta = @entry.amount_delta_cents
    StoredValue::VoidEntry.call(
      entry: @entry,
      store: @store,
      actor: @user,
      reason_code: stored_value_reason_code!("void_reversal")
    )

    @entry.reload
    @account.reload
    assert_equal original_delta, @entry.amount_delta_cents
    assert_equal 0, @account.current_balance_cents
    assert AuditEvent.exists?(event_name: "stored_value.ledger.voided")
  end
end
