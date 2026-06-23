# frozen_string_literal: true

require "test_helper"

class Pos::PostStoredValueLedgerTest < ActiveSupport::TestCase
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_pos_stored_value_tender_permissions!(@user, store: @store)
    grant_permission!(@user, "stored_value.accounts.create", store: @store)
    @account = create_stored_value_account!(issuing_store: @store)
    issue_stored_value_credit!(account: @account, store: @store, actor: @user, amount_cents: 5000)
    @variant = create_product_variant!(selling_price_cents: 2000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
  end

  test "redeems store credit on sale completion" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 2000, extended_price_cents: 2000 } ],
      tenders: [ {
        tender_type: "store_credit",
        amount_cents: 2000,
        line_number: 1,
        stored_value_account: @account
      } ]
    )
    Pos::RecalculateTransaction.call!(transaction)

    entries = Pos::PostStoredValueLedger.call!(transaction:, actor: @user, store: @store).entries

    assert_equal 1, entries.size
    assert_equal "redeem", entries.first.entry_type
    assert_equal(-2000, entries.first.amount_delta_cents)
    assert_equal 3000, @account.reload.current_balance_cents
    assert AuditEvent.exists?(event_name: "pos.stored_value.redeemed")
  end

  test "issues store credit on return completion" do
    customer = create_customer!(home_store: @store)
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      attrs: { customer_id: customer.id, total_cents: -1500 },
      lines: [ { product_variant: @variant, quantity: -1, unit_price_cents: 1500, extended_price_cents: -1500 } ],
      tenders: [ { tender_type: "store_credit", amount_cents: -1500, line_number: 1 } ]
    )
    Pos::RecalculateTransaction.call!(transaction)

    entries = Pos::PostStoredValueLedger.call!(transaction:, actor: @user, store: @store).entries

    assert_equal 1, entries.size
    assert_equal "issue", entries.first.entry_type
    assert_equal 1500, entries.first.amount_delta_cents
    assert_equal customer.id, entries.first.stored_value_account.customer_id
    assert AuditEvent.exists?(event_name: "pos.stored_value.issued")
  end

  test "rejects redemption exceeding balance" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      attrs: { total_cents: 6000 },
      tenders: [ {
        tender_type: "store_credit",
        amount_cents: 6000,
        line_number: 1,
        stored_value_account: @account
      } ]
    )

    error = assert_raises(Pos::PostStoredValueLedger::Error) do
      Pos::PostStoredValueLedger.call!(transaction:, actor: @user, store: @store)
    end
    assert_match(/balance/i, error.message)
  end

  test "generates identifier when requested on issue tender" do
    customer = create_customer!(home_store: @store)
    account = create_stored_value_account!(issuing_store: @store, customer: customer)
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      attrs: { customer_id: customer.id, total_cents: -1500 },
      lines: [ { product_variant: @variant, quantity: -1, unit_price_cents: 1500, extended_price_cents: -1500 } ],
      tenders: [ {
        tender_type: "store_credit",
        amount_cents: -1500,
        line_number: 1,
        stored_value_account: account,
        generate_stored_value_identifier: true
      } ]
    )
    Pos::RecalculateTransaction.call!(transaction)

    result = Pos::PostStoredValueLedger.call!(transaction:, actor: @user, store: @store)

    assert_equal 1, result.entries.size
    assert_equal 1, result.generated_identifiers.size
    tender = transaction.pos_tenders.first.reload
    assert tender.stored_value_identifier_id.present?
    assert_equal account.id, tender.stored_value_account_id
  end
end
