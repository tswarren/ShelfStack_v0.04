# frozen_string_literal: true

require "test_helper"

class InventoryAdjustmentsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase4_permissions!(@user, store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    login_user!(@user, workstation: @workstation)
  end

  test "create post and view adjustment" do
    post inventory_adjustments_path, params: {
      inventory_adjustment: {
        adjustment_type: "manual_adjustment",
        notes: "Test adjustment",
        inventory_adjustment_lines_attributes: {
          "0" => { product_variant_id: @variant.id, quantity_delta: 4, line_number: 1 }
        }
      }
    }
    assert_redirected_to inventory_adjustment_path(InventoryAdjustment.last)
    adjustment = InventoryAdjustment.last

    patch post_inventory_adjustment_path(adjustment)
    assert_redirected_to inventory_adjustment_path(adjustment)
    assert_equal "posted", adjustment.reload.status

    get inventory_root_path
    assert_response :success
    assert_includes response.body, @variant.sku
  end

  test "cancel draft adjustment" do
    adjustment = create_inventory_adjustment!(
      store: @store,
      lines: [ { product_variant: @variant, quantity_delta: 1, line_number: 1 } ]
    )

    patch cancel_inventory_adjustment_path(adjustment)
    assert_redirected_to inventory_adjustments_path
    assert_equal "cancelled", adjustment.reload.status
  end
end
