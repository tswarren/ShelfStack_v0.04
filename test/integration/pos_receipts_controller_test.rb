# frozen_string_literal: true

require "test_helper"

class PosReceiptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @cashier = create_user!(username: "receipt_cashier")
    grant_all_phase6_permissions!(@cashier, store: @store)

    @variant = create_product_variant!(sku: "RCP-ISBN-001", selling_price_cents: 1500)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @cashier, quantity: 5)

    login_user!(@cashier, workstation: @workstation)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @cashier)
  end

  test "show renders 80mm receipt layout from snapshots" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [{
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1500,
        extended_price_cents: 1500
      }]
    )
    complete_pos_sale!(transaction: transaction, user: @cashier, register_session: @register_session)
    receipt = transaction.reload.pos_receipt

    get pos_receipt_path(receipt)
    assert_response :success
    assert_includes response.body, "ss-receipt-80mm"
    assert_includes response.body, @store.name
    assert_includes response.body, receipt.receipt_number
    assert_includes response.body, "RCP-ISBN-001"
    assert_not_includes response.body, "ss-pos-receipt-table"
    assert_includes response.body, "Thank you for shopping with us."
  end
end
