# frozen_string_literal: true

require "test_helper"

class StoredValue::TransferTest < ActiveSupport::TestCase
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @user = create_user!
    @from = create_stored_value_account!(issuing_store: @store)
    @to = create_stored_value_account!(issuing_store: @store, account_type: "gift_card")
    @reason = stored_value_reason_code!("transfer")
    StoredValue::Issue.call(
      account: @from, store: @store, actor: @user, amount_cents: 2000, reason_code: stored_value_reason_code!
    )
    @from.reload
  end

  test "transfer creates paired entries and preserves total liability" do
    total_before = @from.current_balance_cents + @to.current_balance_cents

    StoredValue::Transfer.call(
      from_account: @from,
      to_account: @to,
      store: @store,
      actor: @user,
      amount_cents: 750,
      reason_code: @reason
    )

    @from.reload
    @to.reload
    total_after = @from.current_balance_cents + @to.current_balance_cents
    assert_equal total_before, total_after
    assert_equal 1250, @from.current_balance_cents
    assert_equal 750, @to.current_balance_cents
    assert AuditEvent.exists?(event_name: "stored_value.ledger.transferred")
  end
end
