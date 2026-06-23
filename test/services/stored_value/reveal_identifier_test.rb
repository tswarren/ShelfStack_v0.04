# frozen_string_literal: true

require "test_helper"

class StoredValue::RevealIdentifierTest < ActiveSupport::TestCase
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @user = create_user!
    @account = create_stored_value_account!(issuing_store: @store)
    @identifier = StoredValue::CreateIdentifier.call(
      account: @account,
      actor: @user,
      identifier_type: "generated"
    )
  end

  test "reveals stored identifier and audits" do
    value = StoredValue::RevealIdentifier.call(identifier: @identifier, actor: @user)

    assert_equal 16, value.length
    assert AuditEvent.exists?(event_name: "stored_value.identifier.revealed")
  end

  test "legacy identifier without encrypted value cannot be revealed" do
    @identifier.update_column(:encrypted_value, nil)

    assert_raises(StoredValue::RevealIdentifier::Error) do
      StoredValue::RevealIdentifier.call(identifier: @identifier, actor: @user)
    end
  end
end
