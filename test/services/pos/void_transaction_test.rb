# frozen_string_literal: true

require "test_helper"

class Pos::VoidTransactionTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical", selling_price_cents: 1000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 5)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 } ]
    )
    complete_pos_sale!(transaction: @transaction, user: @user, register_session: @register_session)
    @transaction.reload
  end

  test "void reversal assigns new line_number and copies structured fields" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 } ]
    )
    Pos::RecalculateTransaction.call!(transaction)
    Pos::SettlementSync.call!(
      transaction: transaction,
      tender_inputs: [
        {
          tender_type: "card",
          amount_dollars: format("%.2f", transaction.total_cents / 100.0),
          card_brand: "visa",
          card_last_four: "4242",
          card_authorization_code: "AUTH1"
        }
      ]
    )
    complete_pos_transaction!(
      transaction: transaction.reload,
      completed_by_user: @user,
      register_session: @register_session,
      confirmed_inactive: true
    )
    original = transaction.pos_tenders.settlement_rows.sole

    authorization = grant_void_authorization!(transaction: transaction, requested_by: @user)
    Pos::VoidTransaction.call!(
      transaction: transaction.reload,
      voided_by_user: @user,
      register_session: @register_session,
      reason_code: "cashier_error",
      pos_authorization: authorization
    )

    reversal = transaction.pos_tenders.find_by!(reverses_tender_id: original.id)
    assert_not_equal original.line_number, reversal.line_number
    assert_equal "visa", reversal.card_brand
    assert_equal "4242", reversal.card_last_four
    assert_equal "AUTH1", reversal.card_authorization_code
    assert_equal(-original.amount_cents, reversal.amount_cents)
    assert AuditEvent.exists?(event_name: "pos.settlement.void_reversed", auditable: transaction)
  end

  test "void creates pos_void posting and reversing tenders" do
    authorization = grant_void_authorization!(transaction: @transaction, requested_by: @user)

    pos_void = Pos::VoidTransaction.call!(
      transaction: @transaction,
      voided_by_user: @user,
      register_session: @register_session,
      reason_code: "cashier_error",
      pos_authorization: authorization
    )

    @transaction.reload
    assert @transaction.voided?
    assert_equal authorization.id, pos_void.pos_authorization_id
    assert_not_nil pos_void.inventory_posting
    assert_equal "pos_void", pos_void.inventory_posting.posting_type
    assert_equal @transaction.inventory_posting, pos_void.inventory_posting.reversal_of_posting
    assert @transaction.pos_tenders.where.not(reverses_tender_id: nil).exists?
    assert_equal 5, InventoryBalance.find_by!(store: @store, product_variant: @variant).quantity_on_hand
    assert AuditEvent.exists?(event_name: "pos.transaction.voided", auditable: @transaction)
  end

  test "void preserves original line and tender rows" do
    original_line_attrs = @transaction.pos_transaction_lines.first.attributes.slice(
      "extended_price_cents", "quantity", "unit_price_cents"
    )
    original_tender = @transaction.pos_tenders.first
    original_tender_amount = original_tender.amount_cents

    authorization = grant_void_authorization!(transaction: @transaction, requested_by: @user)
    Pos::VoidTransaction.call!(
      transaction: @transaction,
      voided_by_user: @user,
      register_session: @register_session,
      reason_code: "cashier_error",
      pos_authorization: authorization
    )

    line = @transaction.pos_transaction_lines.first.reload
    assert_equal original_line_attrs, line.attributes.slice("extended_price_cents", "quantity", "unit_price_cents")
    assert_equal original_tender_amount, original_tender.reload.amount_cents
    assert @transaction.pos_tenders.where.not(reverses_tender_id: nil).exists?
  end

  test "void without supervisor authorization raises" do
    assert_raises(Pos::VoidTransaction::Error) do
      Pos::VoidTransaction.call!(
        transaction: @transaction,
        voided_by_user: @user,
        register_session: @register_session,
        reason_code: "cashier_error"
      )
    end
  end
end
