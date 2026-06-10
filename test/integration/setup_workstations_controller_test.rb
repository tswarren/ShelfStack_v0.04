# frozen_string_literal: true

require "test_helper"

class SetupWorkstationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "ws_admin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    grant_permission!(@admin, "setup.workstations.create")
    grant_permission!(@admin, "setup.workstations.update")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "ws_admin", password: "Password123!" }
  end

  test "create with missing fields shows validation errors" do
    post setup_workstations_path, params: { workstation: { store_id: "", name: "" } }

    assert_response :unprocessable_entity
    assert_select ".flash.flash-alert", /can't be blank|must exist/i
  end

  test "update with missing fields shows validation errors" do
    patch setup_workstation_path(@workstation), params: { workstation: { name: "" } }

    assert_response :unprocessable_entity
    assert_select ".flash.flash-alert", /can't be blank/i
  end
end
