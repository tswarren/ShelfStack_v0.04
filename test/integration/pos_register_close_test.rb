# frozen_string_literal: true

require "test_helper"

class PosRegisterCloseTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "close_cashier")
    ctx = setup_pos_workstation!(user: @cashier, opening_cash_cents: 5000, inventory_qty: 5)
    @store = ctx[:store]
    @workstation = ctx[:workstation]
    @variant = ctx[:variant]
    @register_session = ctx[:register_session]

    create_completed_pos_sale!(
      user: @cashier,
      register_session: @register_session,
      variant: @variant,
      store: @store,
      workstation: @workstation,
      quantity: 1,
      unit_price_cents: 2000
    )
  end

  test "close ignores tampered expected cash and stores computed summary value" do
    summary = Pos::RegisterSessionSummary.for(@register_session)
    counted_cents = summary.expected_closing_cash_cents + 100

    assert_difference -> { AuditEvent.where(event_name: "pos.register_session.closed", auditable: @register_session).count }, 1 do
      patch close_pos_register_session_path(@register_session), params: {
        expected_closing_cash_dollars: "9999.99",
        counted_closing_cash_dollars: format("%.2f", counted_cents / 100.0)
      }
    end

    assert_redirected_to pos_root_path
    @register_session.reload

    assert_equal summary.expected_closing_cash_cents, @register_session.expected_closing_cash_cents
    assert_equal counted_cents, @register_session.counted_closing_cash_cents
    assert_equal 100, @register_session.counted_closing_cash_cents - @register_session.expected_closing_cash_cents
    assert_equal "closed", @register_session.status
  end

  test "normal close succeeds when suspended transactions remain on workstation" do
    create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: { status: "suspended", suspended_at: Time.current },
      lines: [ {
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 2000,
        extended_price_cents: 2000
      } ]
    )

    summary = Pos::RegisterSessionSummary.for(@register_session)
    patch close_pos_register_session_path(@register_session), params: {
      counted_closing_cash_dollars: format("%.2f", summary.expected_closing_cash_cents / 100.0)
    }

    assert_redirected_to pos_root_path
    assert_equal "closed", @register_session.reload.status
    assert_equal 1, PosTransaction.suspended.where(workstation: @workstation).count
  end

  test "force close requires supervisor authorization" do
    summary = Pos::RegisterSessionSummary.for(@register_session)
    patch force_close_pos_register_session_path(@register_session), params: {
      counted_closing_cash_dollars: format("%.2f", summary.expected_closing_cash_cents / 100.0)
    }

    assert_redirected_to pos_register_session_path(@register_session)
    assert_match(/Supervisor authorization required/i, flash[:alert].to_s)
    assert @register_session.reload.open?
  end

  test "force close with authorization records audit when suspended transactions exist" do
    create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: { status: "suspended", suspended_at: Time.current },
      lines: [ {
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 2000,
        extended_price_cents: 2000
      } ]
    )

    authorization = grant_force_close_authorization!(
      register_session: @register_session,
      requested_by: @cashier
    )
    summary = Pos::RegisterSessionSummary.for(@register_session)

    patch force_close_pos_register_session_path(@register_session), params: {
      counted_closing_cash_dollars: format("%.2f", summary.expected_closing_cash_cents / 100.0),
      pos_authorization_id: authorization.id
    }

    assert_redirected_to pos_root_path
    assert_match(/suspended transaction/i, flash[:warning].to_s)
    @register_session.reload
    assert_equal "force_closed", @register_session.status
    assert @register_session.force_closed?

    event = AuditEvent.where(event_name: "pos.register_session.force_closed", auditable: @register_session)
      .find { |entry| entry.event_details["suspended_transaction_count"] == 1 }
    assert event
  end
end
