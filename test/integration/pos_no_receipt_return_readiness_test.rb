# frozen_string_literal: true

require "test_helper"

class PosNoReceiptReturnReadinessTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "no_rcpt_ready_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, opening_cash_cents: 10_000)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @variant = @ctx[:variant]
    @register_session = @ctx[:register_session]

    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      },
      lines: [
        {
          product_variant: @variant,
          quantity: -1,
          unit_price_cents: 1500,
          extended_price_cents: -1500,
          return_disposition: "return_to_stock"
        }
      ]
    )
    Pos::RecalculateTransaction.call!(@transaction, business_date: @register_session.business_date)
  end

  test "edit page shows manager sign-in for no-receipt return" do
    get edit_pos_transaction_path(@transaction)

    assert_response :success
    assert_includes response.body, "No-receipt return requires manager approval"
    assert_includes response.body, "Manager sign-in"
    assert_includes response.body, 'data-authorization-type="no_receipt_return"'
  end

  test "return drawer no receipt section includes open ring return form on edit page" do
    get edit_pos_transaction_path(@transaction)

    assert_response :success
    assert_includes response.body, "Add open-ring return"
    assert_includes response.body, 'entry_action" value="return_no_receipt"'
  end

  test "return drawer no receipt section includes open ring return form on idle landing" do
    @transaction.destroy!

    get pos_root_path

    assert_response :success
    assert_includes response.body, "Add open-ring return"
    assert_includes response.body, 'entry_action" value="return_no_receipt"'
  end
end
