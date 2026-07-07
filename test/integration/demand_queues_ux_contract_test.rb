# frozen_string_literal: true

require "test_helper"

class DemandQueuesUxContractTest < ActionDispatch::IntegrationTest
  include Phase3TestHelper
  include Phase7aTestHelper

  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "demand_ux", password: "Password123!")
    grant_permission!(@user, "demand.access", store: @store)
    grant_permission!(@user, "demand.create", store: @store)
    grant_permission!(@user, "demand.cancel", store: @store)
    grant_permission!(@user, "stock_considerations.access", store: @store)
    grant_permission!(@user, "stock_considerations.create", store: @store)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "demand_ux", password: "Password123!" }
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @demand = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: create_customer!,
      quantity: 1
    )
  end

  test "demand index uses page header filter chips badges and empty state" do
    get demand_root_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Demand"
    assert_select ".ss-page-description", text: /Operational demand queue/
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Stock considerations"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"
    assert_select ".ss-filter-bar a.ss-filter-chip", minimum: 1
    assert_select "label.ss-sr-only[for=?]", "status", text: "Status"
    assert_select "label.ss-sr-only[for=?]", "q", text: "Search demand lines"
    assert_select "table.ss-table .ss-status-badge", text: "Open"
  end

  test "demand index empty state when filters exclude all lines" do
    get demand_root_path, params: { status: "canceled" }

    assert_response :success
    assert_select ".ss-empty-state__title", text: "No demand lines match"
  end

  test "demand show uses page header back link badges and danger zone cancel" do
    get demand_demand_line_path(@demand)

    assert_response :success
    assert_select ".ss-detail-back .ss-btn-tertiary", text: /Back to Demand/
    assert_select ".ss-page-header h1", text: @demand.demand_number
    assert_select ".ss-summary .ss-status-badge", text: "Open"
    assert_select "#demand-cancel-heading", text: "Danger zone"
    assert_select "button.ss-btn-danger", text: "Cancel demand"
    assert_select "#demand-next-action-panel"
  end

  test "new demand form uses page header and canonical form actions" do
    get new_demand_demand_line_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "New demand line"
    assert_select "footer.ss-form-actions button.ss-btn-primary", text: "Create demand"
    assert_select "footer.ss-form-actions a.ss-btn-tertiary", text: "Cancel"
  end

  test "stock considerations index uses page header and empty state" do
    get demand_stock_considerations_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Stock considerations"
    assert_select ".ss-empty-state__title", text: "No stock considerations"
  end

  test "locked out page uses access notice" do
    locked_user = create_user!(username: "demand_locked", password: "Password123!")
    delete logout_path
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "demand_locked", password: "Password123!" }

    get demand_locked_out_path

    assert_response :success
    assert_select ".ss-access-notice__title", text: "Demand"
    assert_select ".ss-access-notice__message", text: /do not have access/
  end
end
