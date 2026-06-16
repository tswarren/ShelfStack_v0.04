# frozen_string_literal: true

require "test_helper"

class Inventory::AdminTaskAuthorizationTest < ActiveSupport::TestCase
  setup do
    Seeds::Phase4Permissions.seed!
    @admin = create_user!(username: "invadmin")
    role = Role.create!(role_key: "inventory_admin", name: "Inventory Admin", active: true)
    permission = Permission.find_by!(permission_key: "inventory.admin.rebuild_balances")
    role.grant_permission!(permission)
    UserRoleAssignment.create!(user: @admin, role: role, scope_type: "global", active: true)
  end

  test "authorize succeeds for user with global rebuild permission" do
    user = Inventory::AdminTaskAuthorization.authorize!(username: @admin.username)
    assert_equal @admin, user
  end

  test "authorize fails without username" do
    assert_raises(Inventory::AdminTaskAuthorization::AuthorizationError) do
      Inventory::AdminTaskAuthorization.authorize!(username: nil)
    end
  end

  test "authorize fails for user without permission" do
    other = create_user!(username: "noperms")
    assert_raises(Inventory::AdminTaskAuthorization::AuthorizationError) do
      Inventory::AdminTaskAuthorization.authorize!(username: other.username)
    end
  end
end
