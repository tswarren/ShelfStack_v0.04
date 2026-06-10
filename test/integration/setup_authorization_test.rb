# frozen_string_literal: true

require "test_helper"

class SetupAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "admin2", password: "Password123!")
    role = Role.create!(role_key: "super_administrator", name: "Super Admin", system_role: true, active: true)
    Permission.active_records.find_each { |p| role.grant_permission!(p) }
    UserRoleAssignment.create!(user: @admin, role: role, scope_type: "global", active: true)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "admin2", password: "Password123!" }
  end

  test "admin can access setup" do
    get setup_root_path
    assert_response :success
  end

  test "unauthorized user cannot access setup" do
    delete logout_path
    user = create_user!(username: "basic", password: "Password123!")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "basic", password: "Password123!" }
    get setup_root_path
    assert_redirected_to setup_locked_out_path
  end
end
