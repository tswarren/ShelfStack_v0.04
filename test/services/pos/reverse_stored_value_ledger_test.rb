# frozen_string_literal: true

require "test_helper"

class Pos::ReverseStoredValueLedgerTest < ActiveSupport::TestCase
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase6_permissions!(@user, store: @store)
    grant_pos_stored_value_tender_permissions!(@user, store: @store)
    grant_permission!(@user, "stored_value.accounts.create", store: @store)
    @account = create_stored_value_account!(issuing_store: @store)
    issue_stored_value_credit!(account: @account, store: @store, actor: @user, amount_cents: 5000)
    @variant = create_product_variant!(selling_price_cents: 2000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 5)
    @session = open_register_session!(store: @store, workstation: @workstation, user: @user)
  end

  test "void reverses stored value ledger entries" do
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
    Pos::RecalculateTransaction.call!(transaction, business_date: @session.business_date)
    tender = transaction.pos_tenders.first
    tender.update!(amount_cents: transaction.total_cents)
    complete_pos_sale!(transaction: transaction.reload, user: @user, register_session: @session)
    assert_equal 5000 - transaction.total_cents, @account.reload.current_balance_cents

    authorization = grant_void_authorization!(transaction: transaction, requested_by: @user)
    Pos::VoidTransaction.call!(
      transaction: transaction.reload,
      voided_by_user: @user,
      register_session: @session,
      reason_code: "test_void",
      pos_authorization: authorization
    )

    assert_equal 5000, @account.reload.current_balance_cents
    assert AuditEvent.exists?(event_name: "pos.stored_value.void_reversed")
  end
end
