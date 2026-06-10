# frozen_string_literal: true

require "test_helper"

class SetupUserRoleAssignmentsTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "role_admin", user_type: "admin", password: "Password123!")
    @target = create_user!(username: "target_user", password: "Password123!")
    @role = create_role!(role_key: "store_manager", name: "Store Manager")
    grant_permission!(@admin, "setup.access")
    grant_permission!(@admin, "setup.users.view")
    grant_permission!(@admin, "setup.user_roles.manage")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "role_admin", password: "Password123!" }
  end

  test "user show lists role assignments" do
    UserRoleAssignment.create!(
      user: @target,
      role: @role,
      scope_type: "store",
      store: @store,
      active: true,
      assigned_at: Time.current
    )

    get setup_user_path(@target)
    assert_response :success
    assert_match(/Store Manager/, response.body)
    assert_match(/Role Assignments/, response.body)
  end

  test "authorized user can assign and remove role from user show" do
    post assign_role_setup_user_path(@target),
      params: { role_id: @role.id, scope_type: "global" }
    assert_redirected_to setup_user_path(@target)
    assert_match(/assigned/i, flash[:notice])

    assignment = @target.user_role_assignments.active_records.find_by!(role: @role, scope_type: "global")

    patch remove_role_setup_user_path(@target, assignment_id: assignment.id)
    assert_redirected_to setup_user_path(@target)
    assert_match(/removed/i, flash[:notice])
    assert_not assignment.reload.active?
  end

  test "assign role creates audit event" do
    assert_difference -> { AuditEvent.where(event_name: "user.role_added").count }, 1 do
      post assign_role_setup_user_path(@target),
        params: { role_id: @role.id, scope_type: "global" }
    end
  end
end
