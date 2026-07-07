# frozen_string_literal: true

require "test_helper"

class InventoryUxContractTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase4_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)
  end

  test "inventory index uses page header and primary new adjustment action" do
    get inventory_root_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Store Inventory"
    page_actions = css_select(".ss-page-actions").first.to_s
    assert_operator page_actions.index("New Opening Inventory"), :<, page_actions.index("New Adjustment")
    assert_select ".ss-page-actions .ss-btn-primary", text: "New Adjustment"
    assert_select ".ss-filter-bar .ss-filter-chip--active", text: "All stock"
  end

  test "adjustments index uses page header with primary new action" do
    get inventory_adjustments_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Inventory Adjustments"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"
  end

  test "draft adjustment show orders edit cancel before post" do
    variant = create_product_variant!(inventory_behavior: "standard_physical")
    adjustment = create_inventory_adjustment!(
      store: @store,
      lines: [ { product_variant: variant, quantity_delta: 2, line_number: 1 } ]
    )

    get inventory_adjustment_path(adjustment)

    assert_response :success
    page_actions = css_select(".ss-page-actions").first.to_s
    assert_operator page_actions.index("Edit"), :<, page_actions.index("Cancel")
    assert_operator page_actions.index("Cancel"), :<, page_actions.index("Post")
    assert_select ".ss-page-actions .ss-btn-primary", text: "Post"
  end

  test "admin tools use contract buttons" do
    get inventory_admin_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Inventory Admin Tools"
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Rebuild Balances"
    assert_select ".ss-page-actions .ss-btn-tertiary", text: "Back to Inventory"
  end
end
