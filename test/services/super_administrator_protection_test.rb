# frozen_string_literal: true

require "test_helper"

class SuperAdministratorProtectionTest < ActiveSupport::TestCase
  setup do
    @super_admin = Role.find_or_create_by!(role_key: ShelfStack::SUPER_ADMINISTRATOR_ROLE_KEY) do |role|
      role.name = "Super Administrator"
      role.system_role = true
      role.active = true
    end
    Permission.active_records.find_each { |permission| @super_admin.grant_permission!(permission) }
    @admin = create_user!(username: "seed_admin", user_type: "admin")
    UserRoleAssignment.create!(user: @admin, role: @super_admin, scope_type: "global", active: true)
  end

  test "restore! reactivates super administrator role and grants all permissions" do
    @super_admin.inactivate!
    @super_admin.revoke_permission!(Permission.find_by!(permission_key: "setup.access"))

    SuperAdministratorProtection.restore!

    @super_admin.reload
    assert @super_admin.active?
    assert Authorization.allowed?(user: @admin, permission_key: "setup.access")
  end

  test "cannot revoke permissions from super administrator role" do
    permission = Permission.find_by!(permission_key: "setup.access")

    error = assert_raises(SuperAdministratorProtection::Error) do
      SuperAdministratorProtection.ensure_permission_granted!(@super_admin, permission)
    end

    assert_match(/cannot be removed/i, error.message)
  end
end

class SuperAdministratorProtectionIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @super_admin = Role.find_or_create_by!(role_key: ShelfStack::SUPER_ADMINISTRATOR_ROLE_KEY) do |role|
      role.name = "Super Administrator"
      role.system_role = true
      role.active = true
    end
    Permission.active_records.find_each { |permission| @super_admin.grant_permission!(permission) }
    @admin = create_user!(username: "setup_admin", user_type: "admin", password: "Password123!")
    UserRoleAssignment.create!(user: @admin, role: @super_admin, scope_type: "global", active: true)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "setup_admin", password: "Password123!" }
  end

  test "system user cannot be modified through setup controller" do
    system_user = User.create!(
      user_type: "system",
      username: ShelfStack::SYSTEM_USERNAME,
      first_name: "System",
      last_name: "User",
      display_name: "System User",
      password: SecureRandom.hex(16),
      interactive_login_enabled: false,
      active: true
    )

    patch setup_user_path(system_user), params: { user: { first_name: "Changed" } }
    assert_redirected_to setup_user_path(system_user)
    assert_match(/cannot be modified/i, flash[:alert])

    system_user.reload
    assert_equal "System", system_user.first_name
  end

  test "user without setup access sees locked out page" do
    delete logout_path
    user = create_user!(username: "basic", password: "Password123!")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "basic", password: "Password123!" }

    get setup_root_path
    assert_redirected_to setup_locked_out_path
    follow_redirect!
    assert_response :success
    assert_match(/Setup Access Required/i, response.body)
  end
end
