# frozen_string_literal: true

require "test_helper"

class PosCashMovementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "cash_movement_cashier")
    ctx = setup_pos_workstation!(user: @cashier, opening_cash_cents: 5000, login: false)
    @store = ctx[:store]
    @workstation = ctx[:workstation]
    @register_session = ctx[:register_session]
  end

  test "requires pos.cash_movements.create permission" do
    restricted = create_user!(username: "cash_movement_restricted")
    grant_permission!(restricted, "pos.access", store: @store)
    grant_permission!(restricted, "pos.register_sessions.view", store: @store)
    login_user!(restricted, workstation: @workstation)

    refute Authorization.allowed?(
      user: restricted,
      permission_key: "pos.cash_movements.create",
      store: @store
    )

    before_count = PosCashMovement.count
    post pos_register_session_cash_movements_path(@register_session), params: {
      movement_type: "paid_in",
      amount_dollars: "10.00",
      reason_code: "bank_deposit"
    }

    assert_redirected_to pos_root_path
    assert_equal before_count, PosCashMovement.count
    follow_redirect!
    assert_match(/not authorized/i, flash[:alert].to_s)
  end

  test "records paid in movement with audit and updates expected drawer" do
    login_user!(@cashier, workstation: @workstation)

    assert_difference -> { PosCashMovement.count }, 1 do
      assert_difference -> { AuditEvent.where(event_name: "pos.cash_movement.recorded").count }, 1 do
        post pos_register_session_cash_movements_path(@register_session), params: {
          movement_type: "paid_in",
          amount_dollars: "25.00",
          reason_code: "bank_deposit"
        }
      end
    end

    assert_redirected_to pos_register_session_path(@register_session)
    movement = PosCashMovement.order(:id).last
    assert_equal "paid_in", movement.movement_type
    assert_equal 2500, movement.amount_cents

    summary = Pos::RegisterSessionSummary.for(@register_session.reload)
    assert_equal 7500, summary.expected_closing_cash_cents
  end

  test "records paid out movement" do
    login_user!(@cashier, workstation: @workstation)

    post pos_register_session_cash_movements_path(@register_session), params: {
      movement_type: "paid_out",
      amount_dollars: "15.00",
      reason_code: "petty_cash"
    }

    assert_redirected_to pos_register_session_path(@register_session)
    movement = PosCashMovement.order(:id).last
    assert_equal "paid_out", movement.movement_type
    assert_equal 1500, movement.amount_cents

    summary = Pos::RegisterSessionSummary.for(@register_session.reload)
    assert_equal 3500, summary.expected_closing_cash_cents
  end
end
