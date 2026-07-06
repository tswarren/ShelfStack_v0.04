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

  test "vendor show uses page header status badge and button partial actions" do
    vendor = create_vendor!(name: "Showcase Vendor")

    get setup_vendor_path(vendor)

    assert_response :success
    assert_select ".ss-page-header h1", text: "Showcase Vendor"
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select ".ss-status-badge.status-active", text: "Active"
  end
end
