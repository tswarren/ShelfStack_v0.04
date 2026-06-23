# frozen_string_literal: true

module Phase7bTestHelper
  def seed_phase7b_reference_data!
    Seeds::Phase7bPermissions.seed!
    Seeds::Phase7bStoredValue.seed!
  end

  def grant_all_phase7b_permissions!(user, store: nil)
    Seeds::Phase7bPermissions::PERMISSIONS.each do |attrs|
      grant_permission!(user, attrs[:key], store: store)
    end
  end

  def create_stored_value_account!(attrs = {})
    attrs = attrs.dup
    store = attrs.delete(:issuing_store)
    store ||= create_store!(store_number: format("%03d", Store.count + 1))
    StoredValueAccount.create!(
      {
        issuing_store: store,
        account_type: "merchandise_credit",
        current_balance_cents: 0,
        active: true
      }.merge(attrs)
    )
  end

  def stored_value_reason_code!(key = "manual_issue")
    StoredValueReasonCode.find_by!(reason_key: key)
  end

  def generate_test_identifier!(account:, actor:)
    StoredValue::CreateIdentifier.call(
      account: account,
      actor: actor,
      identifier_type: "generated"
    )
  end
end
