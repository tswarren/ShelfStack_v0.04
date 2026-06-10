# frozen_string_literal: true

require "test_helper"

class UserRoleAssignmentServiceTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @user = create_user!(username: "bookseller")
    @role = create_role!(role_key: "bookseller", name: "Bookseller")
  end

  test "assigns global role to user" do
    assignment = UserRoleAssignmentService.assign!(
      user: @user,
      role: @role,
      scope_type: "global",
      assigned_by: create_user!(username: "assigner")
    )

    assert assignment.active?
    assert assignment.global_scoped?
    assert_equal @role, assignment.role
  end

  test "assigns store-scoped role to user" do
    assignment = UserRoleAssignmentService.assign!(
      user: @user,
      role: @role,
      scope_type: "store",
      store: @store
    )

    assert assignment.store_scoped?
    assert_equal @store, assignment.store
  end

  test "reactivates inactive assignment" do
    assignment = UserRoleAssignmentService.assign!(user: @user, role: @role, scope_type: "global")
    UserRoleAssignmentService.remove!(assignment: assignment)

    reactivated = UserRoleAssignmentService.assign!(user: @user, role: @role, scope_type: "global")

    assert_equal assignment.id, reactivated.id
    assert reactivated.active?
  end

  test "rejects duplicate active assignment" do
    UserRoleAssignmentService.assign!(user: @user, role: @role, scope_type: "global")

    error = assert_raises(UserRoleAssignmentService::Error) do
      UserRoleAssignmentService.assign!(user: @user, role: @role, scope_type: "global")
    end

    assert_match(/already exists/i, error.message)
  end

  test "rejects assignment to system user" do
    system_user = User.create!(
      user_type: "system",
      username: "system",
      first_name: "System",
      last_name: "User",
      display_name: "System User",
      password: SecureRandom.hex(16),
      interactive_login_enabled: false,
      active: true
    )

    error = assert_raises(UserRoleAssignmentService::Error) do
      UserRoleAssignmentService.assign!(user: system_user, role: @role, scope_type: "global")
    end

    assert_match(/system user/i, error.message)
  end

  test "cannot remove last global super administrator assignment" do
    super_admin = Role.find_or_create_by!(role_key: ShelfStack::SUPER_ADMINISTRATOR_ROLE_KEY) do |role|
      role.name = "Super Administrator"
      role.system_role = true
      role.active = true
    end
    admin = create_user!(username: "only_admin", user_type: "admin")
    assignment = UserRoleAssignmentService.assign!(
      user: admin,
      role: super_admin,
      scope_type: "global"
    )

    error = assert_raises(SuperAdministratorProtection::Error) do
      UserRoleAssignmentService.remove!(assignment: assignment)
    end

    assert_match(/last active super administrator/i, error.message)
  end
end
