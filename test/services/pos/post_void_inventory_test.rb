# frozen_string_literal: true

require "test_helper"

class Pos::PostVoidInventoryTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
  end

  test "returns nil when original transaction has no inventory posting" do
    sub_department = create_product_variant!.sub_department
    create_store_tax_category_rate!(store: @store, tax_category: sub_department.default_tax_category)

    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ {
        line_type: "open_ring",
        line_number: 1,
        open_ring_description: "Gift wrap",
        sub_department: sub_department,
        quantity: 1,
        unit_price_cents: 500,
        extended_price_cents: 500
      } ]
    )
    Pos::RecalculateTransaction.call!(transaction, business_date: @register_session.business_date)
    create_pos_tender!(transaction, tender_type: "cash", amount_cents: transaction.total_cents)
    complete_pos_transaction!(
      transaction: transaction.reload,
      completed_by_user: @user,
      register_session: @register_session,
      confirmed_inactive: true
    )
    transaction.reload
    assert_nil transaction.inventory_posting

    authorization = grant_void_authorization!(transaction: transaction, requested_by: @user)
    pos_void = Pos::VoidTransaction.call!(
      transaction: transaction,
      voided_by_user: @user,
      register_session: @register_session,
      reason_code: "cashier_error",
      pos_authorization: authorization
    )

    assert_nil Pos::PostVoidInventory.call(pos_void:, posted_by_user: @user)
    assert_nil pos_void.reload.inventory_posting
  end
end
