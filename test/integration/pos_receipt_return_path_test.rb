# frozen_string_literal: true

require "test_helper"

class PosReceiptReturnPathTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "receipt_return_cashier")
    @ctx = setup_pos_workstation!(user: @cashier)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @variant = @ctx[:variant]
    @register_session = @ctx[:register_session]
  end

  test "receipt with return_to completed links back to completed workspace" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [ {
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1500,
        extended_price_cents: 1500
      } ]
    )
    complete_pos_sale!(transaction: transaction, user: @cashier, register_session: @register_session)
    receipt = transaction.reload.pos_receipt

    get pos_receipt_path(receipt, return_to: "completed")

    assert_response :success
    assert_select "a[href=?]", completed_pos_transaction_path(transaction), text: "Back to completed sale"
  end

  test "completed workspace receipt links include return_to completed" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [ {
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1500,
        extended_price_cents: 1500
      } ]
    )
    complete_pos_sale!(transaction: transaction, user: @cashier, register_session: @register_session)
    receipt = transaction.reload.pos_receipt

    get completed_pos_transaction_path(transaction)

    assert_response :success
    assert_includes response.body, pos_receipt_path(receipt, return_to: "completed")
  end
end
