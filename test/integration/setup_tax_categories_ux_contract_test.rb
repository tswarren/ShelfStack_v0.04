# frozen_string_literal: true

require "test_helper"

class SetupTaxCategoriesUxContractTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "tax_ux_admin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    grant_permission!(@admin, "setup.tax_categories.view")
    grant_permission!(@admin, "setup.tax_categories.create")
    grant_permission!(@admin, "setup.tax_categories.update")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "tax_ux_admin", password: "Password123!" }
  end

  test "tax category index uses page header table and status badges when rows exist" do
    tax_category = create_tax_category!(name: "Maps Tax", short_name: "Maps")

    get setup_tax_categories_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Tax Categories"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"
    assert_select ".ss-table"
    assert_select ".ss-status-badge.status-active", text: "Active"
    assert_select "a[href='#{setup_tax_category_path(tax_category)}']", text: "View"
  end

  test "tax category index shows empty state when no tax categories exist" do
    TaxCategory.delete_all

    get setup_tax_categories_path

    assert_response :success
    assert_select ".ss-empty-state"
    assert_select ".ss-empty-state__title", text: "No tax categories yet"
    assert_select ".ss-empty-state__actions .ss-btn-primary", text: "New"
  end

  test "tax category show separates edit lifecycle and destructive actions" do
    tax_category = create_tax_category!(name: "Books Tax", short_name: "Books")

    get setup_tax_category_path(tax_category)

    assert_response :success
    assert_select ".ss-detail-back .ss-btn-tertiary", text: /Back to Tax Categories/
    assert_select ".ss-page-header h1", text: "Books Tax"
    page_actions = css_select(".ss-page-actions").first.to_s
    assert_operator page_actions.index("Inactivate"), :<, page_actions.index("Edit")
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Inactivate"
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select ".ss-page-actions .ss-btn-danger", count: 0
    assert_select ".ss-detail-actions", count: 0
    assert_select ".ss-status-badge.status-active", text: "Active"
    assert_select "#tax-category-danger-zone-heading", text: "Danger zone"
    assert_select ".ss-section-actions .ss-btn-danger", text: "Delete tax category"
  end

  test "tax category show uses secondary edit and primary reactivate when inactive" do
    tax_category = create_tax_category!(name: "Inactive Tax", short_name: "Inact", active: false)

    get setup_tax_category_path(tax_category)

    assert_response :success
    page_actions = css_select(".ss-page-actions").first.to_s
    assert_operator page_actions.index("Edit"), :<, page_actions.index("Reactivate")
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Edit"
    assert_select ".ss-page-actions .ss-btn-primary", text: "Reactivate"
    assert_select ".ss-status-badge.status-inactive", text: "Inactive"
  end

  test "tax category form uses primary submit and tertiary cancel" do
    tax_category = create_tax_category!(name: "Form Tax", short_name: "Form")

    get new_setup_tax_category_path
    assert_response :success
    form_actions = css_select(".ss-form-actions").first.to_s
    assert_operator form_actions.index("Create Tax Category"), :<, form_actions.index("Cancel")
    assert_select ".ss-form-actions .ss-btn-primary", text: "Create Tax Category"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"

    get edit_setup_tax_category_path(tax_category)
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Update Tax Category"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"
  end
end
