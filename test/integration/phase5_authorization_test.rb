# frozen_string_literal: true

require "test_helper"

class Phase5AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
  end

  test "user without orders access is redirected to locked out" do
    login_user!(@user, workstation: @workstation)
    get orders_root_path
    assert_redirected_to orders_locked_out_path
  end

  test "user with orders access can view orders home" do
    grant_permission!(@user, "orders.access", store: @store)
    login_user!(@user, workstation: @workstation)
    get orders_root_path
    assert_response :success
  end

  test "purchase orders require view permission" do
    grant_permission!(@user, "orders.access", store: @store)
    login_user!(@user, workstation: @workstation)
    get orders_purchase_orders_path
    assert_redirected_to root_path
  end
end
