# frozen_string_literal: true

require "test_helper"

class Phase7bStoredValueAdminIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7b_permissions!(@user, store: @store)
    grant_permission!(@user, "customers.access", store: @store)
    login_user!(@user, workstation: @workstation)
    @customer = create_customer!(home_store: @store)
  end

  test "creates customer-linked account" do
    post customers_stored_value_accounts_path, params: {
      stored_value_account: {
        issuing_store_id: @store.id,
        customer_id: @customer.id,
        account_type: "merchandise_credit"
      }
    }
    assert_redirected_to customers_stored_value_account_path(StoredValueAccount.last)
    assert AuditEvent.exists?(event_name: "stored_value.account.created")
  end

  test "shows masked identifier not raw value" do
    account = create_stored_value_account!(issuing_store: @store, customer: @customer)
    identifier = generate_test_identifier!(account: account, actor: @user)

    get customers_stored_value_account_path(account)
    assert_response :success
    assert_includes response.body, identifier.display_value_masked
    assert_not_includes response.body, identifier.lookup_digest
    assert_not_includes response.body, StoredValue::IdentifierVault.decrypt(identifier.encrypted_value)
  end

  test "reveal full identifier with permission" do
    account = create_stored_value_account!(issuing_store: @store)
    identifier = generate_test_identifier!(account: account, actor: @user)

    post reveal_customers_stored_value_account_identifier_path(account, identifier)

    assert_redirected_to customers_stored_value_account_path(account)
    assert AuditEvent.exists?(event_name: "stored_value.identifier.revealed")
    follow_redirect!
    formatted = StoredValue::IdentifierCodec.format_display(
      StoredValue::IdentifierVault.decrypt(identifier.encrypted_value)
    )
    assert_includes response.body, formatted
  end

  test "denies reveal without permission" do
    account = create_stored_value_account!(issuing_store: @store)
    identifier = generate_test_identifier!(account: account, actor: @user)
    UserRoleAssignment.where(user: @user).delete_all
    grant_permission!(@user, "customers.access", store: @store)
    grant_permission!(@user, "stored_value.accounts.view", store: @store)

    post reveal_customers_stored_value_account_identifier_path(account, identifier)

    assert_redirected_to customers_root_path
    assert_not AuditEvent.exists?(event_name: "stored_value.identifier.revealed")
  end

  test "denies issue without permission" do
    account = create_stored_value_account!(issuing_store: @store)
    UserRoleAssignment.where(user: @user).delete_all
    grant_permission!(@user, "customers.access", store: @store)
    grant_permission!(@user, "stored_value.accounts.view", store: @store)

    post issue_customers_stored_value_account_operations_path(account), params: {
      amount_cents: 100,
      reason_code_id: stored_value_reason_code!.id
    }
    assert_redirected_to customers_root_path
  end

  test "reactivates suspended account" do
    account = create_stored_value_account!(issuing_store: @store)
    account.suspend!

    patch reactivate_customers_stored_value_account_path(account)

    assert_redirected_to customers_stored_value_account_path(account)
    assert account.reload.active?
    assert AuditEvent.exists?(event_name: "stored_value.account.reactivated")
  end

  test "phase 6 still rejects gift_card tender type" do
    assert_includes PosTender::PHASE6_ALLOWED_TYPES, "cash"
    assert_not_includes PosTender::PHASE6_ALLOWED_TYPES, "gift_card"
    assert_not_includes PosTender::PHASE6_ALLOWED_TYPES, "store_credit"
  end
end
