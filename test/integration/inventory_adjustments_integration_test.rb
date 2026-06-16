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
    assert AuditEvent.exists?(event_name: "inventory_adjustment.cancelled", auditable: adjustment)
  end

  test "multi line adjustment posts and updates multiple balances" do
    variant_two = create_product_variant!(
      sub_department: @variant.sub_department,
      inventory_behavior: "standard_physical"
    )
    post inventory_adjustments_path, params: {
      inventory_adjustment: {
        adjustment_type: "manual_adjustment",
        notes: "Multi line",
        inventory_adjustment_lines_attributes: {
          "0" => { product_variant_id: @variant.id, quantity_delta: 2, line_number: 1 },
          "1" => { product_variant_id: variant_two.id, quantity_delta: 5, line_number: 2 }
        }
      }
    }
    adjustment = InventoryAdjustment.last
    patch post_inventory_adjustment_path(adjustment)
    assert_equal "posted", adjustment.reload.status
    assert_equal 2, adjustment.inventory_posting.inventory_ledger_entries.count
    assert_equal 2, InventoryBalance.find_by!(store: @store, product_variant: @variant).quantity_on_hand
    assert_equal 5, InventoryBalance.find_by!(store: @store, product_variant: variant_two).quantity_on_hand
  end

  test "posted adjustment show includes audit timeline and posting info" do
    adjustment = create_inventory_adjustment!(
      store: @store,
      lines: [ { product_variant: @variant, quantity_delta: 3, line_number: 1 } ]
    )
    patch post_inventory_adjustment_path(adjustment)

    get inventory_adjustment_path(adjustment)
    assert_response :success
    assert_includes response.body, "Audit Timeline"
    assert_includes response.body, "Posting"
    assert_includes response.body, "Ledger"
  end
end
