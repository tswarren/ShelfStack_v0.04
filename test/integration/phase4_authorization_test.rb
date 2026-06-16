# frozen_string_literal: true

require "test_helper"

class Phase4AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
  end

  test "user without inventory access is redirected to locked out" do
    login_user!(@user, workstation: @workstation)
    get inventory_root_path
    assert_redirected_to inventory_locked_out_path
  end

  test "user with balances view can access inventory index" do
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
    login_user!(@user, workstation: @workstation)
    get inventory_root_path
    assert_response :success
  end
end
