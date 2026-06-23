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

  def grant_pos_stored_value_tender_permissions!(user, store:)
    %w[pos.tenders.store_credit pos.tenders.gift_card pos.refunds.store_credit].each do |key|
      next if Authorization.allowed?(user: user, permission_key: key, store: store)

      grant_permission!(user, key, store: store)
    end
  end

  def issue_stored_value_credit!(account:, store:, actor:, amount_cents:)
    StoredValue::Issue.call(
      account: account,
      store: store,
      actor: actor,
      amount_cents: amount_cents,
      reason_code: stored_value_reason_code!("manual_issue")
    )
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
