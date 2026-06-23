# frozen_string_literal: true

require "test_helper"

class Pos::PostGiftCardSaleLedgerTest < ActiveSupport::TestCase
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_pos_stored_value_tender_permissions!(@user, store: @store)
    ensure_gift_card_sale_classification!(store: @store)
    @session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    @transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @user)
    @line = add_gift_card_sale_line!(transaction: @transaction, actor: @user, amount_cents: 2500)
    @transaction.pos_tenders.create!(
      tender_type: "cash",
      amount_cents: 2500,
      line_number: 1
    )
    Pos::RecalculateTransaction.call!(@transaction, business_date: @session.business_date)
  end

  test "issues gift card balance for new card sale line" do
    Pos::CompleteTransaction.call!(
      transaction: @transaction.reload,
      completed_by_user: @user,
      register_session: @session,
      confirmed_inactive: true
    )

    account = @line.reload.stored_value_account
    assert_equal "gift_card", account.account_type
    assert_equal 2500, account.current_balance_cents
    entry = StoredValueLedgerEntry.find_by!(source: @line)
    assert_equal "issue", entry.entry_type
    assert_equal "pos_gift_card_sale", entry.reason_code.reason_key
    assert AuditEvent.exists?(event_name: "pos.gift_card.sold")
  end

  test "reload increases existing gift card balance" do
    account = create_stored_value_account!(issuing_store: @store, account_type: "gift_card", current_balance_cents: 1000)
    identifier = generate_test_identifier!(account: account, actor: @user)
    raw = StoredValue::IdentifierVault.decrypt(identifier.encrypted_value)

    Pos::UpdateGiftCardSaleLine.call!(
      line: @line,
      actor: @user,
      lookup_code: raw,
      generate_identifier: false
    )

    Pos::CompleteTransaction.call!(
      transaction: @transaction.reload,
      completed_by_user: @user,
      register_session: @session,
      confirmed_inactive: true
    )

    assert_equal account.id, @line.reload.stored_value_account_id
    assert_equal 3500, account.reload.current_balance_cents
  end

  test "assigns manual card number for new gift card sale line" do
    card_number = StoredValue::IdentifierCodec.generate[:normalized_value]

    Pos::UpdateGiftCardSaleLine.call!(
      line: @line,
      actor: @user,
      lookup_code: card_number
    )

    Pos::CompleteTransaction.call!(
      transaction: @transaction.reload,
      completed_by_user: @user,
      register_session: @session,
      confirmed_inactive: true
    )

    @line.reload
    assert_equal card_number, StoredValue::IdentifierVault.decrypt(@line.stored_value_identifier.encrypted_value)
    assert_equal 2500, @line.stored_value_account.current_balance_cents
  end

  test "clearing card number restores auto-generation" do
    Pos::UpdateGiftCardSaleLine.call!(
      line: @line,
      actor: @user,
      clear_card_number: true
    )

    assert @line.reload.generate_stored_value_identifier?
    assert_nil @line.stored_value_account_id
    assert_nil @line.stored_value_identifier_id
  end

  test "rejects manual card number with invalid check digit" do
    error = assert_raises(Pos::UpdateGiftCardSaleLine::Error) do
      Pos::UpdateGiftCardSaleLine.call!(
        line: @line,
        actor: @user,
        lookup_code: "4246270017419099"
      )
    end

    assert_match(/check digit/i, error.message)
    assert_nil @line.reload.stored_value_account_id
  end
end
