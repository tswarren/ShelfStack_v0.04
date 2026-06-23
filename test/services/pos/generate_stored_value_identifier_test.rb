# frozen_string_literal: true

require "test_helper"

class Pos::GenerateStoredValueIdentifierTest < ActiveSupport::TestCase
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @user = create_user!
    grant_pos_stored_value_tender_permissions!(@user, store: @store)
    @account = create_stored_value_account!(issuing_store: @store)
  end

  test "generates identifier for refund issue tender" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: create_workstation!(store: @store),
      user: @user,
      attrs: { total_cents: -1000 },
      tenders: [ {
        tender_type: "store_credit",
        amount_cents: -1000,
        line_number: 1,
        stored_value_account: @account,
        generate_stored_value_identifier: true
      } ]
    )
    tender = transaction.pos_tenders.first

    generated = Pos::GenerateStoredValueIdentifier.call!(tender:, actor: @user, store: @store)

    assert generated.display_value.present?
    assert_equal tender.id, generated.pos_tender_id
    assert tender.reload.stored_value_identifier_id.present?
    assert AuditEvent.exists?(event_name: "stored_value.identifier.created")
  end
end
