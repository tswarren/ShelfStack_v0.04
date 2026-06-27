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
  end

  test "idle landing renders command field and new sale secondary action" do
    get pos_root_path

    assert_response :success
    assert_select "input[data-pos-command-bar-target='input']"
    assert_select "button", text: "New sale"
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

  test "root route_command gc stub does not create draft or auto-post gift card" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_route_command_path, params: { input: "/gc 50" }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "disabled_command", body["action"]
  end
end
