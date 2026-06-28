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

  test "route_command close blocked with active draft" do
    grant_permission!(@cashier, "pos.register_sessions.close", store: @store)

    post route_command_pos_transaction_path(@transaction), params: { input: "/close" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "message", body["action"]
    assert_equal Pos::CommandRouteBuilder::CLOSE_BLOCKED_MESSAGE, body["message"]
  end

  test "route_command reports confirms when active draft exists" do
    grant_permission!(@cashier, "pos.reports.view", store: @store)

    post route_command_pos_transaction_path(@transaction), params: { input: "/rp" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "reports_confirm_offer", body["action"]
    assert_equal Rails.application.routes.url_helpers.reports_root_path, body.dig("payload", "url")
    assert_equal Pos::CommandRouteBuilder::REPORTS_CONFIRM_MESSAGE, body["message"]
  end

  test "route_command session returns drawer offer without changing transaction" do
    grant_permission!(@cashier, "pos.register_sessions.view", store: @store)
    line_count_before = @transaction.pos_transaction_lines.count

    post route_command_pos_transaction_path(@transaction), params: { input: "/session" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "session_drawer_offer", body["action"]
    assert_equal "session", body.dig("payload", "focus")
    assert_equal line_count_before, @transaction.reload.pos_transaction_lines.count
  end

  test "route_command held returns drawer offer focused on held sales" do
    grant_permission!(@cashier, "pos.transactions.view", store: @store)

    post route_command_pos_transaction_path(@transaction), params: { input: "/held" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "session_drawer_offer", body["action"]
    assert_equal "held", body.dig("payload", "focus")
  end

  test "route_command cashin returns cash movement offer" do
    grant_permission!(@cashier, "pos.cash_movements.create", store: @store)

    post route_command_pos_transaction_path(@transaction), params: { input: "/cashin 10" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "cash_movement_offer", body["action"]
    assert_equal "paid_in", body.dig("payload", "movement_type")
    assert_equal 1000, body.dig("payload", "amount_cents")
  end
end
