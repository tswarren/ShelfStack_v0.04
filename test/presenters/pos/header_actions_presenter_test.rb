# frozen_string_literal: true

require "test_helper"

class Pos::HeaderActionsPresenterTest < ActiveSupport::TestCase
  setup do
    @user = create_user!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    grant_all_phase6_permissions!(@user, store: @store)
    @register_session = open_register_session!(
      store: @store,
      workstation: @workstation,
      user: @user,
      opening_cash_cents: 5000
    )
  end

  test "balance action available when register is closed" do
    close_register!(@register_session, user: @user)

    actions = Pos::HeaderActionsPresenter.build(
      user: @user,
      store: @store,
      register_session: nil,
      context: :root
    )
    balance = actions.find { |action| action.key == :balance }
    cashin = actions.find { |action| action.key == :cashin }

    assert balance.available
    assert_not cashin.available
    assert_equal Pos::CommandRegistry::NO_REGISTER_SESSION_MESSAGE, cashin.message
  end

  test "register actions available when session is open" do
    actions = Pos::HeaderActionsPresenter.build(
      user: @user,
      store: @store,
      register_session: @register_session,
      context: :root
    )

    assert actions.find { |action| action.key == :balance }.available
    assert actions.find { |action| action.key == :cashin }.available
    assert actions.find { |action| action.key == :session }.available
  end

  test "actions include stimulus handlers for command bar" do
    actions = Pos::HeaderActionsPresenter.build(
      user: @user,
      store: @store,
      register_session: @register_session,
      context: :root
    )

    assert_equal "showBalanceModal", actions.find { |action| action.key == :balance }.stimulus_action
    assert_equal "openCashIn", actions.find { |action| action.key == :cashin }.stimulus_action
  end

  private

  def close_register!(register_session, user:)
    Pos::RegisterSessionLifecycle.close!(
      session: register_session,
      closed_by_user: user,
      expected_closing_cash_cents: 5000,
      counted_closing_cash_cents: 5000,
      force: false
    )
  end
end
