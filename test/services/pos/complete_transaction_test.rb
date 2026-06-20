# frozen_string_literal: true

require "test_helper"

class Pos::CompleteTransactionTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical", selling_price_cents: 1000)
    @tax_category = @variant.sub_department.default_tax_category
    create_store_tax_category_rate!(store: @store, tax_category: @tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 5)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        extended_price_cents: 1000
      }]
    )
  end

  test "completes sale with inventory posting and receipt number" do
    complete_pos_sale!(transaction: @transaction, user: @user, register_session: @register_session)

    @transaction.reload
    assert @transaction.completed?
    assert_equal "sale", @transaction.transaction_type
    assert @transaction.transaction_number.present?
    assert_equal @transaction.transaction_number, @transaction.pos_receipt.receipt_number

    posting = @transaction.inventory_posting
    assert_not_nil posting
    assert_equal "pos_transaction", posting.posting_type
    assert_equal 1, posting.inventory_ledger_entries.count
    entry = posting.inventory_ledger_entries.first
    assert_equal "sold", entry.movement_type
    assert_equal(-1, entry.quantity_delta)

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 4, balance.quantity_on_hand
  end

  test "completes even exchange without tenders when total is zero" do
    @transaction.pos_transaction_lines.create!(
      line_number: 2,
      line_type: "variant",
      product_variant: @variant,
      product: @variant.product,
      quantity: -1,
      unit_price_cents: 1000,
      extended_price_cents: -1000
    )
    Pos::RecalculateTransaction.call!(@transaction, business_date: @register_session.business_date)
    assert @transaction.total_cents.zero?
    grant_no_receipt_return_authorization!(@transaction)

    Pos::CompleteTransaction.call!(
      transaction: @transaction.reload,
      completed_by_user: @user,
      register_session: @register_session,
      confirmed_inactive: true
    )

    @transaction.reload
    assert @transaction.completed?
    assert_equal "exchange", @transaction.transaction_type
    assert_empty @transaction.pos_tenders
  end

  test "completes even exchange with explicit zero cash tender" do
    @transaction.pos_transaction_lines.create!(
      line_number: 2,
      line_type: "variant",
      product_variant: @variant,
      product: @variant.product,
      quantity: -1,
      unit_price_cents: 1000,
      extended_price_cents: -1000
    )
    Pos::RecalculateTransaction.call!(@transaction, business_date: @register_session.business_date)

    grant_no_receipt_return_authorization!(@transaction)
    Pos::TenderSync.call!(
      transaction: @transaction,
      tender_inputs: [{ tender_type: "cash", amount_dollars: "0.00" }]
    )

    Pos::CompleteTransaction.call!(
      transaction: @transaction.reload,
      completed_by_user: @user,
      register_session: @register_session,
      confirmed_inactive: true
    )

    @transaction.reload
    assert @transaction.completed?
    assert_equal "exchange", @transaction.transaction_type
    assert_equal 0, @transaction.pos_tenders.sum(&:amount_cents)
  end

  private

  def grant_no_receipt_return_authorization!(transaction)
    manager = create_user!(username: "manager-#{SecureRandom.hex(4)}", pin: "4321")
    grant_permission!(manager, "pos.authorizations.grant", store: @store)
    Pos::AuthorizationRequest.grant!(
      authorization_type: "no_receipt_return",
      requested_by: @user,
      manager_username: manager.username,
      manager_pin: "4321",
      store: @store,
      pos_transaction: transaction
    )
  end
end
