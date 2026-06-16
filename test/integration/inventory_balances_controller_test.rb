# frozen_string_literal: true

require "test_helper"

class InventoryBalancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase4_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase4_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)
  end

  test "index shows balances with cost column and pagination" do
    variant = create_product_variant!(inventory_behavior: "standard_physical")
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: variant, quantity_delta: 2, line_number: 1 } ]
      ),
      user: @user
    )

    get inventory_root_path
    assert_response :success
    assert_includes response.body, variant.sku
    assert_includes response.body, "Cost Value"
    assert_includes response.body, "New Opening Inventory"
  end
end
