# frozen_string_literal: true

require "test_helper"

class Phase4AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase4_reference_data!
    @store_one = create_store!(store_number: "001", name: "Store One")
    @store_two = create_store!(store_number: "002", name: "Store Two")
    @workstation = create_workstation!(store: @store_one)
    @user = create_user!
  end

  test "user without inventory access is redirected to locked out" do
    login_user!(@user, workstation: @workstation)
    get inventory_root_path
    assert_redirected_to inventory_locked_out_path
  end

  test "user with balances view can access inventory index" do
    grant_permission!(@user, "inventory.access", store: @store_one)
    grant_permission!(@user, "inventory.balances.view", store: @store_one)
    login_user!(@user, workstation: @workstation)
    get inventory_root_path
    assert_response :success
  end

  test "adjustment permissions are enforced" do
    grant_permission!(@user, "inventory.access", store: @store_one)
    grant_permission!(@user, "inventory.adjustments.view", store: @store_one)
    login_user!(@user, workstation: @workstation)

    get inventory_adjustments_path
    assert_response :success

    get new_inventory_adjustment_path
    assert_redirected_to root_path
  end

  test "ledger view permission required for variant ledger" do
    grant_permission!(@user, "inventory.access", store: @store_one)
    grant_permission!(@user, "inventory.balances.view", store: @store_one)
    login_user!(@user, workstation: @workstation)
    variant = create_product_variant!(inventory_behavior: "standard_physical")

    get inventory_variant_path(variant)
    assert_redirected_to root_path
  end

  test "negative exceptions require permission" do
    grant_permission!(@user, "inventory.access", store: @store_one)
    login_user!(@user, workstation: @workstation)

    get inventory_negative_path
    assert_redirected_to root_path
  end

  test "enterprise rollup requires permission" do
    grant_permission!(@user, "inventory.access", store: @store_one)
    grant_permission!(@user, "inventory.balances.view", store: @store_one)
    login_user!(@user, workstation: @workstation)

    get inventory_enterprise_path
    assert_redirected_to root_path
  end

  test "admin tools require rebuild permission" do
    grant_permission!(@user, "inventory.access", store: @store_one)
    login_user!(@user, workstation: @workstation)

    get inventory_admin_path
    assert_redirected_to inventory_root_path
  end

  test "store scoped user cannot view other store adjustment" do
    adjustment = create_inventory_adjustment!(store: @store_two)
    grant_permission!(@user, "inventory.access", store: @store_one)
    grant_permission!(@user, "inventory.adjustments.view", store: @store_one)
    login_user!(@user, workstation: @workstation)

    get inventory_adjustment_path(adjustment)
    assert_response :not_found
  end
end
