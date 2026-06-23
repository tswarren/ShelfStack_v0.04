# frozen_string_literal: true

require "test_helper"

class PosReceiptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "receipt_cashier")
    @ctx = setup_pos_workstation!(user: @cashier)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @variant = create_product_variant!(sku: "RCP-ISBN-001", selling_price_cents: 1500, sub_department: @ctx[:variant].sub_department)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @cashier, quantity: 5)
    @register_session = @ctx[:register_session]
  end

  test "show renders 80mm receipt layout from snapshots" do
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

    get pos_receipt_path(receipt)
    assert_response :success
    assert_includes response.body, "ss-receipt-80mm"
    assert_includes response.body, @store.name
    assert_includes response.body, receipt.receipt_number
    assert_includes response.body, "RCP-ISBN-001"
    assert_not_includes response.body, "ss-pos-receipt-table"
    assert_includes response.body, "Thank you for shopping with us."
    assert_includes response.body, "Items at list"
    assert_not_includes response.body, ">Net<"
    assert_includes response.body, "Print"
    assert_includes response.body, "Summary"
    assert_includes response.body, "Menu"
    assert_not_includes response.body, "Reprint"
    assert_select "a[href=?]", pos_transaction_path(transaction), text: "Summary"
  end

  test "print increments reprint count and records audit event" do
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

    assert_difference -> { receipt.reload.reprint_count }, 1 do
      assert_difference -> { AuditEvent.where(event_name: "pos.receipt.printed", auditable: receipt).count }, 1 do
        patch print_pos_receipt_path(receipt), headers: { Accept: "text/vnd.turbo-stream.html" }
      end
    end
    assert_response :no_content
  end

  test "show renders discounted sale with clear line and totals layout" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: { discount_cents: 100 },
      lines: [ {
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1500,
        line_discount_cents: 150,
        extended_price_cents: 1250
      } ]
    )
    Pos::RecalculateTransaction.call!(transaction, business_date: @register_session.business_date)
    complete_pos_sale!(transaction: transaction.reload, user: @cashier, register_session: @register_session)
    receipt = transaction.reload.pos_receipt

    get pos_receipt_path(receipt)
    assert_response :success
    assert_includes response.body, "List price"
    assert_includes response.body, "Item discount"
    assert_includes response.body, "Items at list"
    assert_includes response.body, "Subtotal"
    assert_includes response.body, "Order discount"
    assert_not_includes response.body, ">Net<"
    assert_not_includes response.body, ">Orig<"
  end

  test "show renders return line with single header amount and detail text" do
    sale = create_pos_transaction!(
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
    Pos::RecalculateTransaction.call!(sale, business_date: @register_session.business_date)
    complete_pos_sale!(transaction: sale, user: @cashier, register_session: @register_session)

    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [ {
        product_variant: @variant,
        quantity: -1,
        unit_price_cents: 1500,
        extended_price_cents: -1500,
        return_disposition: "return_to_stock",
        source_transaction: sale,
        source_transaction_line: sale.pos_transaction_lines.first
      } ]
    )
    Pos::RecalculateTransaction.call!(return_txn, business_date: @register_session.business_date)
    complete_pos_sale!(
      transaction: return_txn.reload,
      user: @cashier,
      register_session: @register_session,
      tenders: [ { tender_type: "cash", amount_cents: return_txn.total_cents } ]
    )
    receipt = return_txn.reload.pos_receipt

    get pos_receipt_path(receipt)
    assert_response :success
    assert_includes response.body, "Return"
    assert_includes response.body, "Return to stock"
    assert_includes response.body, "From receipt #{sale.transaction_number}"
    assert_not_includes response.body, "Return value"
    assert_not_includes response.body, "Original price"
  end

  test "show renders gift card sale line with card number and new balance" do
    seed_phase7b_reference_data!
    grant_pos_stored_value_tender_permissions!(@cashier, store: @store)
    ensure_gift_card_sale_classification!(store: @store)

    transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @cashier)
    add_gift_card_sale_line!(transaction: transaction, actor: @cashier, amount_cents: 2500)
    complete_pos_sale!(transaction: transaction.reload, user: @cashier, register_session: @register_session)

    line = transaction.pos_transaction_lines.first
    card_number = StoredValue::IdentifierCodec.format_display(
      StoredValue::IdentifierVault.decrypt(line.stored_value_identifier.encrypted_value)
    )
    receipt = transaction.reload.pos_receipt

    get pos_receipt_path(receipt)
    assert_response :success
    assert_includes response.body, "Card number"
    assert_includes response.body, card_number
    assert_includes response.body, "Value"
    assert_includes response.body, "$25.00"
    assert_includes response.body, "New balance"
    assert_includes response.body, "$25.00"
  end
end
