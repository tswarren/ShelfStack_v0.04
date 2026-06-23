# frozen_string_literal: true

require "test_helper"

class Phase7bPosStoredValueIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase6_permissions!(@user, store: @store)
    grant_pos_stored_value_tender_permissions!(@user, store: @store)
    grant_permission!(@user, "stored_value.accounts.create", store: @store)
    @variant = create_product_variant!(selling_price_cents: 3000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 10)
    login_user!(@user, workstation: @workstation)
    @session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    @account = create_stored_value_account!(issuing_store: @store)
    issue_stored_value_credit!(account: @account, store: @store, actor: @user, amount_cents: 5000)
  end

  test "redeems store credit on completed sale" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 3000, extended_price_cents: 3000 } ]
    )
    Pos::RecalculateTransaction.call!(transaction, business_date: @session.business_date)
    total = transaction.total_cents

    Pos::SettlementSync.call!(
      transaction: transaction,
      tender_inputs: [ {
        tender_type: "store_credit",
        amount_cents: total,
        stored_value_account_id: @account.id
      } ],
      actor: @user
    )

    Pos::CompleteTransaction.call!(
      transaction: transaction.reload,
      completed_by_user: @user,
      register_session: @session,
      confirmed_inactive: true
    )

    assert_equal "completed", transaction.reload.status
    assert_equal 5000 - total, @account.reload.current_balance_cents
    assert_equal 1, StoredValueLedgerEntry.where(entry_type: "redeem", stored_value_account: @account).count
  end

  test "issues store credit on return with customer" do
    customer = create_customer!(home_store: @store)
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      attrs: { customer_id: customer.id },
      lines: [ { product_variant: @variant, quantity: -1, unit_price_cents: 3000, extended_price_cents: -3000 } ]
    )
    Pos::RecalculateTransaction.call!(transaction, business_date: @session.business_date)

    Pos::SettlementSync.call!(
      transaction: transaction,
      tender_inputs: [ { tender_type: "store_credit", amount_cents: transaction.total_cents, generate_identifier: true } ],
      actor: @user
    )
    grant_no_receipt_return_authorization!(transaction, requested_by: @user)

    Pos::CompleteTransaction.call!(
      transaction: transaction.reload,
      completed_by_user: @user,
      register_session: @session,
      confirmed_inactive: true
    )

    account = StoredValueAccount.find_by!(customer_id: customer.id, account_type: "merchandise_credit")
    assert_equal transaction.total_cents.abs, account.current_balance_cents
    tender = transaction.pos_tenders.settlement_rows.find_by!(tender_type: "store_credit")
    assert tender.stored_value_identifier_id.present?
    assert AuditEvent.exists?(event_name: "pos.stored_value.issued")
  end

  test "issues bearer store credit on return with generated identifier" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: -1, unit_price_cents: 3000, extended_price_cents: -3000 } ]
    )
    Pos::RecalculateTransaction.call!(transaction, business_date: @session.business_date)

    Pos::SettlementSync.call!(
      transaction: transaction,
      tender_inputs: [ { tender_type: "store_credit", amount_cents: transaction.total_cents, generate_identifier: true } ],
      actor: @user
    )
    grant_no_receipt_return_authorization!(transaction, requested_by: @user)

    Pos::CompleteTransaction.call!(
      transaction: transaction.reload,
      completed_by_user: @user,
      register_session: @session,
      confirmed_inactive: true
    )

    tender = transaction.pos_tenders.settlement_rows.find_by!(tender_type: "store_credit")
    account = tender.stored_value_account
    assert account.present?
    assert_nil account.customer_id
    assert_equal transaction.total_cents.abs, account.current_balance_cents
    assert tender.stored_value_identifier_id.present?
  end

  test "lookup endpoint returns masked account details" do
    identifier = generate_test_identifier!(account: @account, actor: @user)
    raw = StoredValue::IdentifierVault.decrypt(identifier.encrypted_value)

    get pos_stored_value_lookup_path(code: raw, tender_type: "store_credit")

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "found", payload["status"]
    assert_equal @account.id, payload["account_id"]
    assert_equal identifier.display_value_masked, payload["display_value_masked"]
  end

  test "rejects store credit tender without actor permissions" do
    UserRoleAssignment.where(user: @user).delete_all
    grant_permission!(@user, "pos.access", store: @store)
    grant_permission!(@user, "pos.tenders.cash", store: @store)
    grant_permission!(@user, "pos.transactions.complete", store: @store)

    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      attrs: { total_cents: 1000 },
      tenders: [ {
        tender_type: "store_credit",
        amount_cents: 1000,
        line_number: 1,
        stored_value_account: @account
      } ]
    )

    error = assert_raises(Pos::TenderValidator::Error) do
      Pos::TenderValidator.validate!(transaction, actor: @user)
    end
    assert_match(/not enabled/i, error.message)
  end
end
