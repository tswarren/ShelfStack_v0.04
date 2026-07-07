# frozen_string_literal: true

require "test_helper"

class SetupPr4bSurfacesUxContractTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "pr4b_ux_admin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    %w[
      setup.roles.view setup.roles.create setup.roles.update setup.roles.inactivate
      setup.permissions.view
      setup.workstations.view setup.workstations.create setup.workstations.update setup.workstations.inactivate
      setup.product_conditions.view setup.product_conditions.create setup.product_conditions.update setup.product_conditions.inactivate
      setup.display_locations.view
      setup.inventory_reason_codes.view setup.inventory_reason_codes.create
      setup.stored_value_reason_codes.view
      setup.tax_exception_reasons.view setup.tax_exception_reasons.create setup.tax_exception_reasons.update
      setup.store_tax_rates.view setup.store_tax_rates.create
      setup.store_tax_category_rates.view
    ].each { |key| grant_permission!(@admin, key) }
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "pr4b_ux_admin", password: "Password123!" }
  end

  test "roles index and show follow setup UX contract" do
    role = create_role!(role_key: "ux_role_#{SecureRandom.hex(3)}", name: "UX Role")

    get setup_roles_path
    assert_response :success
    assert_select ".ss-page-header h1", text: "Roles"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"
    assert_select ".ss-status-badge.status-active", text: "Active"

    get setup_role_path(role)
    assert_response :success
    assert_select ".ss-detail-back .ss-btn-tertiary", text: /Back to Roles/
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Inactivate"
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select "#role-danger-zone-heading", text: "Danger zone"
  end

  test "permissions index uses page header and status badges" do
    get setup_permissions_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Permissions"
    assert_select ".ss-status-badge", minimum: 1
  end

  test "workstations index and show follow setup UX contract" do
    get setup_workstations_path
    assert_response :success
    assert_select ".ss-page-header h1", text: "Workstations"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"

    get setup_workstation_path(@workstation)
    assert_response :success
    assert_select ".ss-page-header h1", text: @workstation.name
    assert_select "#workstation-danger-zone-heading", text: "Danger zone"
  end

  test "product conditions index uses page header" do
    condition = create_product_condition!(condition_key: "ux_cond_#{SecureRandom.hex(3)}", name: "UX Condition", short_name: "UX")

    get setup_product_conditions_path
    assert_response :success
    assert_select ".ss-page-header h1", text: "Product Conditions"

    get setup_product_condition_path(condition)
    assert_response :success
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select "#product-condition-danger-zone-heading", text: "Danger zone"
  end

  test "store tax rates index uses page header and filter chips when multiple stores" do
    create_store!(store_number: "002", name: "Second Store")

    get setup_store_tax_rates_path
    assert_response :success
    assert_select ".ss-page-header h1", text: "Store Tax Rates"
    assert_select ".ss-filter-bar a.ss-filter-chip", minimum: 2
  end

  test "tax exception reason forms use primary submit and tertiary cancel" do
    get new_setup_tax_exception_reason_path
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Create Tax Exception Reason"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"
  end
end
