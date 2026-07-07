# frozen_string_literal: true

require "test_helper"

class SetupVendorsUxContractTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "vendor_ux_admin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    grant_permission!(@admin, "setup.vendors.view")
    grant_permission!(@admin, "setup.vendors.create")
    grant_permission!(@admin, "setup.vendors.update")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "vendor_ux_admin", password: "Password123!" }
  end

  test "vendor index uses page header table and status badges when rows exist" do
    vendor = create_vendor!(name: "Pilot Vendor")

    get setup_vendors_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Vendors"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"
    assert_select ".ss-table"
    assert_select ".ss-status-badge.status-active", text: "Active"
    assert_select "a[href='#{setup_vendor_path(vendor)}']", text: "View"
  end

  test "vendor index shows empty state when no vendors exist" do
    Vendor.delete_all

    get setup_vendors_path

    assert_response :success
    assert_select ".ss-empty-state"
    assert_select ".ss-empty-state__title", text: "No vendors yet"
    assert_select ".ss-empty-state__actions .ss-btn-primary", text: "New"
  end

  test "vendor show separates edit lifecycle and destructive actions" do
    vendor = create_vendor!(name: "Showcase Vendor")

    get setup_vendor_path(vendor)

    assert_response :success
    assert_select ".ss-page-header h1", text: "Showcase Vendor"
    page_actions = css_select(".ss-page-actions").first.to_s
    assert_operator page_actions.index("Inactivate"), :<, page_actions.index("Edit")
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Inactivate"
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select ".ss-page-actions .ss-btn-danger", count: 0
    assert_select ".ss-detail-actions", count: 0
    assert_select ".ss-status-badge.status-active", text: "Active"
    assert_select "#vendor-danger-zone-heading", text: "Danger zone"
    assert_select ".ss-section-actions .ss-btn-danger", text: "Delete vendor"
  end

  test "vendor show uses secondary edit and primary reactivate when inactive" do
    vendor = create_vendor!(name: "Inactive Vendor", active: false)

    get setup_vendor_path(vendor)

    assert_response :success
    page_actions = css_select(".ss-page-actions").first.to_s
    assert_operator page_actions.index("Edit"), :<, page_actions.index("Reactivate")
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Edit"
    assert_select ".ss-page-actions .ss-btn-primary", text: "Reactivate"
    assert_select ".ss-detail-actions", count: 0
    assert_select ".ss-status-badge.status-inactive", text: "Inactive"
  end

  test "vendor form uses primary submit and tertiary cancel" do
    vendor = create_vendor!(name: "Form Vendor")

    get new_setup_vendor_path
    assert_response :success
    form_actions = css_select(".ss-form-actions").first.to_s
    assert_operator form_actions.index("Create Vendor"), :<, form_actions.index("Cancel")
    assert_select ".ss-form-actions .ss-btn-primary", text: "Create Vendor"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"

    get edit_setup_vendor_path(vendor)
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Update Vendor"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"
  end
end
