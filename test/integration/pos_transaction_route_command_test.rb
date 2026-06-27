# frozen_string_literal: true

require "test_helper"

class PosTransactionRouteCommandTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "txn_route_cmd_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, login: true, grant_permissions: false, inventory_qty: 0)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @register_session = @ctx[:register_session]
    @variant = @ctx[:variant]

    grant_permission!(@cashier, "pos.access", store: @store)
    grant_permission!(@cashier, "pos.transactions.update", store: @store)

    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      },
      lines: [
        { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 }
      ]
    )
  end

  test "route_command cash works with tender permission but without line add permission" do
    grant_permission!(@cashier, "pos.tenders.cash", store: @store)

    post route_command_pos_transaction_path(@transaction), params: { input: "/cash" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "settlement_offer", body["action"]
    assert_equal "cash", body.dig("payload", "tender_type")
  end

  test "route_command cash denied without tender permission even with line add permission" do
    grant_permission!(@cashier, "pos.lines.add", store: @store)

    post route_command_pos_transaction_path(@transaction), params: { input: "/cash" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "message", body["action"]
    assert_equal Pos::CommandRegistry::PERMISSION_DENIED_MESSAGE, body["message"]
  end

  test "route_command requires transaction update permission" do
    restricted = create_user!(username: "txn_route_cmd_restricted")
    grant_permission!(restricted, "pos.access", store: @store)
    grant_permission!(restricted, "pos.tenders.cash", store: @store)
    delete logout_path
    login_user!(restricted, workstation: @workstation)

    post route_command_pos_transaction_path(@transaction), params: { input: "/cash" }, as: :json

    assert_redirected_to pos_root_path
  end
end
