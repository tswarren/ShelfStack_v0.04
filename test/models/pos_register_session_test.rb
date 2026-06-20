# frozen_string_literal: true

require "test_helper"

class PosRegisterSessionTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
  end

  test "only one open session per workstation" do
    Pos::RegisterSessionLifecycle.open!(
      store: @store,
      workstation: @workstation,
      opened_by_user: @user,
      business_date: Date.current
    )

    assert_raises(Pos::RegisterSessionLifecycle::Error) do
      Pos::RegisterSessionLifecycle.open!(
        store: @store,
        workstation: @workstation,
        opened_by_user: @user,
        business_date: Date.current
      )
    end
  end
end
