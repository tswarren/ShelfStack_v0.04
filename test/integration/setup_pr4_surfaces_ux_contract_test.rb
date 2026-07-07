# frozen_string_literal: true

require "test_helper"
require_relative "../../db/seeds/phase85_permissions"

class SetupPr4SurfacesUxContractTest < ActionDispatch::IntegrationTest
  setup do
    Seeds::Phase85Permissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "pr4_ux_admin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    %w[
      setup.formats.view setup.formats.create setup.formats.update
      setup.discount_reasons.view setup.discount_reasons.create setup.discount_reasons.update
      setup.stores.view setup.stores.create setup.stores.update
      setup.users.view setup.users.create setup.users.update
      setup.sub_departments.view setup.sub_departments.create setup.sub_departments.update
      setup.departments.view setup.departments.create setup.departments.update
    ].each { |key| grant_permission!(@admin, key) }
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "pr4_ux_admin", password: "Password123!" }
  end

  test "formats index and show follow setup UX contract" do
    format = create_format!(format_key: "ux_fmt_#{SecureRandom.hex(3)}", name: "UX Format", short_name: "UX")

    get setup_formats_path
    assert_response :success
    assert_select ".ss-page-header h1", text: "Formats"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"
    assert_select ".ss-status-badge.status-active", text: "Active"

    get setup_format_path(format)
    assert_response :success
    assert_select ".ss-detail-back .ss-btn-tertiary", text: /Back to Formats/
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Inactivate"
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select "#format-danger-zone-heading", text: "Danger zone"
    assert_select ".ss-section-actions .ss-btn-danger", text: "Delete format"
  end

  test "formats forms use primary submit and tertiary cancel" do
    format = create_format!(format_key: "ux_form_#{SecureRandom.hex(3)}", name: "Form Format", short_name: "FF")

    get new_setup_format_path
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Create Format"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"

    get edit_setup_format_path(format)
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Update Format"
  end

  test "discount reasons index and show follow setup UX contract" do
    reason = DiscountReason.create!(
      reason_key: "ux_dr_#{SecureRandom.hex(4)}",
      name: "UX Discount Reason",
      active: true
    )

    get setup_discount_reasons_path
    assert_response :success
    assert_select ".ss-page-header h1", text: "Discount Reasons"
    assert_select ".ss-status-badge.status-active", text: "Active"

    get setup_discount_reason_path(reason)
    assert_response :success
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Inactivate"
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select ".ss-page-actions .ss-btn-danger", count: 0
    assert_select ".ss-detail-actions", count: 0
  end

  test "discount reason forms use primary submit and tertiary cancel" do
    reason = DiscountReason.create!(
      reason_key: "ux_dr_form_#{SecureRandom.hex(4)}",
      name: "UX Form Reason",
      active: true
    )

    get new_setup_discount_reason_path
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Create Discount Reason"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"

    get edit_setup_discount_reason_path(reason)
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Update Discount Reason"
  end

  test "stores index and show follow setup UX contract with danger zone" do
    store = create_store!(store_number: format("%03d", SecureRandom.random_number(900) + 100), name: "UX Store #{SecureRandom.hex(2)}")

    get setup_stores_path
    assert_response :success
    assert_select ".ss-page-header h1", text: "Stores"
    assert_select ".ss-status-badge.status-active", text: "Active"

    get setup_store_path(store)
    assert_response :success
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Inactivate"
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select "#store-danger-zone-heading", text: "Danger zone"
    assert_select ".ss-section-actions .ss-btn-danger", text: "Delete store"
  end

  test "store forms use primary submit and tertiary cancel" do
    store = create_store!(store_number: format("%03d", SecureRandom.random_number(900) + 100), name: "Form Store #{SecureRandom.hex(2)}")

    get new_setup_store_path
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Create Store"

    get edit_setup_store_path(store)
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Update Store"
  end

  test "users index and interactive show follow setup UX contract" do
    user = create_user!(username: "ux_show_user_#{SecureRandom.hex(3)}", password: "Password123!")

    get setup_users_path
    assert_response :success
    assert_select ".ss-page-header h1", text: "Users"
    assert_select ".ss-status-badge.status-active", text: "Active"

    get setup_user_path(user)
    assert_response :success
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Inactivate"
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select "#user-danger-zone-heading", text: "Danger zone"
    assert_select ".ss-section-actions .ss-btn-danger", text: "Delete user"
  end

  test "system user show omits lifecycle actions and danger zone" do
    system_user = User.find_or_create_by!(username: ShelfStack::SYSTEM_USERNAME) do |user|
      user.assign_attributes(
        user_type: "system",
        first_name: "ShelfStack",
        last_name: "System",
        display_name: "ShelfStack System",
        interactive_login_enabled: false,
        active: true,
        password: SecureRandom.hex(32)
      )
    end

    get setup_user_path(system_user)
    assert_response :success
    assert_select ".ss-page-actions .ss-btn", count: 0
    assert_select ".ss-alert", text: /System user is read-only/
    assert_select "#user-danger-zone-heading", count: 0
  end

  test "subdepartments index and show follow setup UX contract" do
    sub_department = create_sub_department!

    get setup_sub_departments_path
    assert_response :success
    assert_select ".ss-page-header h1", text: "Subdepartments"
    assert_select ".ss-table.ss-table--tree"
    assert_select ".ss-status-badge.status-active"

    get setup_sub_department_path(sub_department)
    assert_response :success
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Inactivate"
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select "#sub-department-danger-zone-heading", text: "Danger zone"
  end

  test "subdepartment forms use primary submit and tertiary cancel" do
    sub_department = create_sub_department!

    get new_setup_sub_department_path
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Create Subdepartment"

    get edit_setup_sub_department_path(sub_department)
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Update Subdepartment"
  end

  test "departments index and show follow setup UX contract" do
    department = create_department!(
      department_number: format("%03d", SecureRandom.random_number(900) + 100),
      name: "UX Department #{SecureRandom.hex(2)}",
      short_name: "UXD"
    )

    get setup_departments_path
    assert_response :success
    assert_select ".ss-page-header h1", text: "Departments"
    assert_select ".ss-status-badge.status-active", text: "Active"

    get setup_department_path(department)
    assert_response :success
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Inactivate"
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select "#department-danger-zone-heading", text: "Danger zone"
    assert_select ".ss-section-actions .ss-btn-danger", text: "Delete department"
  end

  test "department forms use primary submit and tertiary cancel" do
    department = create_department!(
      department_number: format("%03d", SecureRandom.random_number(900) + 100),
      name: "Form Department #{SecureRandom.hex(2)}",
      short_name: "FD"
    )

    get new_setup_department_path
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Create Department"

    get edit_setup_department_path(department)
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Update Department"
  end
end
