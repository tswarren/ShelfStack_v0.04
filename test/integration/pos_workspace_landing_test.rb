# frozen_string_literal: true

require "test_helper"

class PosWorkspaceLandingTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "workspace_landing_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, login: true, inventory_qty: 0)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @register_session = @ctx[:register_session]
    @variant = @ctx[:variant]
    ensure_gift_card_sale_classification!(store: @store)
    grant_pos_stored_value_tender_permissions!(@cashier, store: @store)
  end

  test "idle landing renders command field and quick actions" do
    get pos_root_path

    assert_response :success
    assert_select "input[data-pos-command-bar-target='input']"
    assert_select "button", text: "Open Ring"
    assert_select "button", text: "Gift Card"
    assert_select ".ss-pos-banner", count: 0
    assert_no_match "New Transaction", response.body
  end

  test "active session-scoped draft redirects to edit" do
    draft = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      }
    )

    get pos_root_path

    assert_redirected_to edit_pos_transaction_path(draft, mode: "sale")
  end

  test "legacy draft shows conflict picker instead of resuming" do
    legacy = create_pos_transaction!(store: @store, workstation: @workstation, user: @cashier)

    get pos_root_path

    assert_response :success
    assert_match "Older draft needs review", response.body
    assert_select "a[href=?]", edit_pos_transaction_path(legacy, mode: "sale")
  end

  test "root route_command scan adds line and redirects to edit" do
    assert_difference -> { PosTransaction.drafts.count }, 1 do
      post pos_route_command_path, params: { input: @variant.sku }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    transaction = PosTransaction.drafts.order(:id).last

    assert_equal "redirect", body["action"]
    assert_equal 1, transaction.pos_transaction_lines.count
    assert_equal @variant.id, transaction.pos_transaction_lines.first.product_variant_id
  end


  test "root route_command receipt-shaped input does not create draft" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "001-001-000042" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "message", body["action"]
    assert_equal Pos::CommandParser::FAILED_LOOKUP_MESSAGE, body["message"]
  end

  test "root route_command bare amount does not create draft" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "20" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "message", body["action"]
  end

  test "root route_command failed lookup does not create draft" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "definitely-not-found" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "message", body["action"]
    assert_equal Pos::CommandParser::FAILED_LOOKUP_MESSAGE, body["message"]
  end

  test "root route_command unknown slash command returns message without creating draft" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "/foo" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "message", body["action"]
    assert_equal Pos::CommandParser::UNKNOWN_COMMAND_MESSAGE, body["message"]
  end

  test "root route_command gc creates draft and adds gift card sale line" do
    assert_difference -> { PosTransaction.count }, 1 do
      post pos_route_command_path, params: { input: "/gc 50" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "redirect", body["action"]
    assert_match %r{/pos/transactions/\d+/edit}, body["payload"]["url"]

    transaction = PosTransaction.order(:id).last
    line = transaction.pos_transaction_lines.find_by!(line_type: "gift_card_sale")
    assert_equal 5000, line.unit_price_cents
  end

  test "root route_command open ring opens drawer without creating draft" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "/op 10" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "open_ring_offer", body["action"]
    assert_equal 1000, body["payload"]["amount_cents"]
  end

  test "root route_command return opens drawer without creating draft" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "/rt 001-001-000042" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "return_drawer_offer", body["action"]
    assert_equal "001-001-000042", body["payload"]["receipt_number"]
  end

  test "root route_command pickup opens drawer without creating draft" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "/pickup" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "pickup_drawer_offer", body["action"]
  end

  test "root route_command help returns structured command list without creating draft" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "/help" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "help", body["action"]
    assert body["payload"]["commands"].is_a?(Array)
    assert body["payload"]["commands"].any? { |entry| entry["key"] == "openring" }
  end

  test "root route_command bare question mark returns help" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "?" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "help", body["action"]
  end

  test "root route_command cash from idle does not create draft" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "/cash" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "message", body["action"]
    assert_equal Pos::CommandRegistry::NO_ACTIVE_TRANSACTION_MESSAGE, body["message"]
  end

  test "idle landing renders session drawer shell" do
    get pos_root_path

    assert_response :success
    assert_select "#pos-session-drawer"
    assert_includes response.body, "Held sales"
  end

  test "root route_command session returns drawer offer without creating draft" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "/session" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "session_drawer_offer", body["action"]
    assert_equal "session", body.dig("payload", "focus")
  end

  test "root route_command held returns drawer offer focused on held sales" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "/held" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "session_drawer_offer", body["action"]
    assert_equal "held", body.dig("payload", "focus")
  end

  test "idle landing renders return and pickup drawer panels" do
    get pos_root_path

    assert_response :success
    assert_includes response.body, 'data-pos-command-bar-target="receiptPanel"'
    assert_includes response.body, 'data-pos-command-bar-target="pickupPanel"'
    assert_includes response.body, 'data-pos-command-bar-target="openRingPanel"'
    assert_includes response.body, "No receipt"
    assert_includes response.body, pos_workspace_add_return_line_path
    assert_includes response.body, pos_workspace_add_no_receipt_line_path
    assert_includes response.body, pos_workspace_add_reservation_line_path
    assert_includes response.body, pos_workspace_add_open_ring_line_path
    assert_includes response.body, "pos-help-modal"
    assert_includes response.body, "POS commands"
  end

  test "root route_command return blocked when active draft has settlement rows" do
    draft = create_pos_transaction!(
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
    create_pos_tender!(draft, tender_type: "cash", amount_cents: 1000)

    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "/return" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "message", body["action"]
    assert_equal Pos::CommandRouteBuilder::RETURN_BLOCKED_TENDERS_MESSAGE, body["message"]
    assert_nil body.dig("payload", "url")
  end

  test "root route_command invalid open ring amount does not create draft" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "/op abc" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "message", body["action"]
    assert_equal Pos::CommandRouteBuilder::INVALID_AMOUNT_MESSAGE, body["message"]
  end

  test "root route_command invalid gift card amount does not create draft" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "/gc abc" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "message", body["action"]
    assert_equal Pos::CommandRouteBuilder::INVALID_AMOUNT_MESSAGE, body["message"]
  end

  test "explicit new sale creates draft and redirects to edit" do
    assert_difference -> { PosTransaction.count }, 1 do
      post pos_transactions_path, params: { mode: "sale" }
    end

    assert_redirected_to %r{/pos/transactions/\d+/edit}
  end
end
