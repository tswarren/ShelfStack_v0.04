# frozen_string_literal: true

require "test_helper"

class InventoryVariantLookupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.adjustments.create", store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical", sku: "LOOKUPSKU001")
    login_user!(@user, workstation: @workstation)
  end

  test "lookup returns variant json" do
    get inventory_variant_lookup_path, params: { q: "LOOKUPSKU001" }
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal "found", body["status"]
    assert_equal @variant.id, body["variants"].first["id"]
    assert_equal 0, body["variants"].first["quantity_on_hand"]
  end

  test "new adjustment from variant preselects line" do
    grant_permission!(@user, "inventory.balances.view", store: @store)
    get new_inventory_adjustment_path(product_variant_id: @variant.id)
    assert_response :success
    assert_includes response.body, "LOOKUPSKU001"
    assert_includes response.body, @variant.name
  end
end
