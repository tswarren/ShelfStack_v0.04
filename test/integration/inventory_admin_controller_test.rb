# frozen_string_literal: true

require "test_helper"

class InventoryAdminControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase4_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.admin.rebuild_balances", store: @store)
    login_user!(@user, workstation: @workstation)
  end

  test "admin can access tools and rebuild balances" do
    variant = create_product_variant!(inventory_behavior: "standard_physical")
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: variant, quantity_delta: 1, line_number: 1 } ]
      ),
      user: @user
    )
    balance = InventoryBalance.find_by!(store: @store, product_variant: variant)
    balance.update_column(:quantity_on_hand, 99)

    get inventory_admin_path
    assert_response :success

    post rebuild_balances_inventory_admin_path
    assert_redirected_to inventory_admin_path
    assert_equal 1, InventoryBalance.find_by!(store: @store, product_variant: variant).quantity_on_hand
  end

  test "integrity check stores result in session" do
    post integrity_check_inventory_admin_path
    assert_redirected_to inventory_admin_path

    get inventory_admin_path
    assert_response :success
    assert_includes response.body, "Integrity Check Result"
  end
end
