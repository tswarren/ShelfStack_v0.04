# frozen_string_literal: true

require "test_helper"

class PosStoredValueIssuanceSlipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase7b_reference_data!
    @cashier = create_user!(username: "slip_cashier")
    @ctx = setup_pos_workstation!(user: @cashier)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @register_session = @ctx[:register_session]
    grant_pos_stored_value_tender_permissions!(@cashier, store: @store)
    ensure_gift_card_sale_classification!(store: @store)
  end

  test "show renders gift card issuance slip with full card number" do
    transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @cashier)
    add_gift_card_sale_line!(transaction: transaction, actor: @cashier, amount_cents: 5000)
    complete_pos_sale!(transaction: transaction.reload, user: @cashier, register_session: @register_session)

    line = transaction.pos_transaction_lines.first
    entry = StoredValueLedgerEntry.find_by!(source: line, entry_type: "issue")
    card_number = StoredValue::IdentifierCodec.format_display(
      StoredValue::IdentifierVault.decrypt(line.stored_value_identifier.encrypted_value)
    )

    get pos_stored_value_issuance_slip_path(entry)
    assert_response :success
    assert_includes response.body, "GIFT CARD"
    assert_includes response.body, card_number
    assert_includes response.body, "Value"
    assert_includes response.body, "$50.00"
    assert_includes response.body, "New balance"
    assert_includes response.body, "Treat this card as cash"
    assert_includes response.body, "Print"
  end

  test "print records audit event" do
    transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @cashier)
    add_gift_card_sale_line!(transaction: transaction, actor: @cashier, amount_cents: 2500)
    complete_pos_sale!(transaction: transaction.reload, user: @cashier, register_session: @register_session)
    entry = StoredValueLedgerEntry.find_by!(source: transaction.pos_transaction_lines.first, entry_type: "issue")

    assert_difference -> { AuditEvent.where(event_name: "pos.stored_value_slip.printed", auditable: entry).count }, 1 do
      patch print_pos_stored_value_issuance_slip_path(entry), headers: { Accept: "text/vnd.turbo-stream.html" }
    end
    assert_response :no_content
  end

  test "completed transaction summary includes print gift card link" do
    transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @cashier)
    add_gift_card_sale_line!(transaction: transaction, actor: @cashier, amount_cents: 2500)
    complete_pos_sale!(transaction: transaction.reload, user: @cashier, register_session: @register_session)

    get pos_transaction_path(transaction)
    assert_response :success
    assert_includes response.body, "Print Gift Card"
  end
end
