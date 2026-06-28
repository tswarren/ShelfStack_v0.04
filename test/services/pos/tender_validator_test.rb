# frozen_string_literal: true

require "test_helper"

class Pos::TenderValidatorTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(selling_price_cents: 10_000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      attrs: { total_cents: 1000 },
      tenders: [ { tender_type: "cash", amount_cents: 1000 } ]
    )
  end

  test "rejects gift card without stored value permissions" do
    account = create_stored_value_account!(issuing_store: @store, account_type: "gift_card")
    @transaction.pos_tenders.destroy_all
    @transaction.pos_tenders.create!(
      tender_type: "gift_card",
      amount_cents: 1000,
      line_number: 1,
      stored_value_account: account
    )
    error = assert_raises(Pos::TenderValidator::Error) { Pos::TenderValidator.validate!(@transaction, actor: @user) }
    assert_match(/gift_card|not enabled/i, error.message)
  end

  test "rejects cash without cash permission" do
    error = assert_raises(Pos::TenderValidator::Error) do
      Pos::TenderValidator.validate!(@transaction, actor: @user)
    end
    assert_match(/cash|not enabled/i, error.message)
  end

  test "allows gift card with policy permissions" do
    seed_phase7b_reference_data!
    grant_permission!(@user, "pos.tenders.gift_card", store: @store)
    account = create_stored_value_account!(issuing_store: @store, account_type: "gift_card")
    issue_stored_value_credit!(account: account, store: @store, actor: @user, amount_cents: 5000)
    @transaction.pos_tenders.destroy_all
    @transaction.pos_tenders.create!(
      tender_type: "gift_card",
      amount_cents: 1000,
      line_number: 1,
      stored_value_account: account
    )

    assert_nothing_raised do
      Pos::TenderValidator.validate!(@transaction, actor: @user)
    end
  end

  test "rejects store credit without permissions" do
    account = create_stored_value_account!(issuing_store: @store)
    @transaction.pos_tenders.destroy_all
    @transaction.pos_tenders.create!(
      tender_type: "store_credit",
      amount_cents: 1000,
      line_number: 1,
      stored_value_account: account
    )

    error = assert_raises(Pos::TenderValidator::Error) { Pos::TenderValidator.validate!(@transaction) }
    assert_match(/store_credit|not enabled/i, error.message)
  end

  test "rejects tender total mismatch" do
    @transaction.pos_tenders.destroy_all
    @transaction.pos_tenders.create!(tender_type: "cash", amount_cents: 900, line_number: 1)

    error = assert_raises(Pos::TenderValidator::Error) { Pos::TenderValidator.validate!(@transaction) }
    assert_match(/does not match transaction total/i, error.message)
  end

  test "requires authorization for cash refund over threshold" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      attrs: { total_cents: -6000 },
      tenders: [ { tender_type: "cash", amount_cents: -6000 } ]
    )

    error = assert_raises(Pos::TenderValidator::Error) { Pos::TenderValidator.validate!(return_txn) }
    assert_match(/Cash refund exceeds threshold/i, error.message)
  end

  test "allows cash refund over threshold with supervisor authorization" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      attrs: { total_cents: -6000 },
      tenders: [ { tender_type: "cash", amount_cents: -6000 } ]
    )
    authorization = grant_cash_refund_authorization!(return_txn)

    assert_nothing_raised do
      Pos::TenderValidator.validate!(return_txn, pos_authorization_id: authorization.id)
    end
  end

  private

  def grant_cash_refund_authorization!(transaction)
    manager = create_user!(username: "refund-manager-#{SecureRandom.hex(4)}", pin: "4321")
    grant_permission!(manager, "pos.authorizations.grant", store: @store)
    Pos::AuthorizationRequest.grant!(
      authorization_type: "cash_refund_over_threshold",
      requested_by: @user,
      manager_username: manager.username,
      manager_pin: "4321",
      store: @store,
      pos_transaction: transaction
    )
  end
end
