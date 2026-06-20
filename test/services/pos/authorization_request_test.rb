# frozen_string_literal: true

require "test_helper"

class Pos::AuthorizationRequestTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @requester = create_user!(username: "cashier")
    @manager = create_user!(username: "manager", pin: "4321")
    grant_permission!(@manager, "pos.authorizations.grant", store: @store)
  end

  test "grants authorization and records audit event" do
    assert_difference -> { AuditEvent.where(event_name: "pos.authorization.granted").count }, 1 do
      authorization = Pos::AuthorizationRequest.grant!(
        authorization_type: "discount_over_limit",
        requested_by: @requester,
        manager_username: @manager.username,
        manager_pin: "4321",
        store: @store
      )

      assert authorization.granted?
      assert_equal "discount_over_limit", authorization.authorization_type
    end
  end

  test "rejects invalid manager pin" do
    assert_raises(Pos::AuthorizationRequest::Error) do
      Pos::AuthorizationRequest.grant!(
        authorization_type: "discount_over_limit",
        requested_by: @requester,
        manager_username: @manager.username,
        manager_pin: "0000",
        store: @store
      )
    end
  end

  test "granted_for_transaction finds persisted authorization without param id" do
    workstation = create_workstation!(store: @store)
    transaction = create_pos_transaction!(store: @store, workstation: workstation, user: @requester, lines: [])

    authorization = Pos::AuthorizationRequest.grant!(
      authorization_type: "no_receipt_return",
      requested_by: @requester,
      manager_username: @manager.username,
      manager_pin: "4321",
      store: @store,
      pos_transaction: transaction
    )

    found = Pos::AuthorizationRequest.granted_for_transaction(
      transaction: transaction,
      authorization_type: "no_receipt_return"
    )

    assert_equal authorization.id, found.id
  end
end
