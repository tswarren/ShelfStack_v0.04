# frozen_string_literal: true

require "test_helper"

class CustomersCustomersUxContractTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "cust_ux_admin", password: "Password123!")
    grant_permission!(@admin, "customers.access")
    grant_permission!(@admin, "customers.create")
    grant_permission!(@admin, "customers.update")
    grant_permission!(@admin, "customers.inactivate")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "cust_ux_admin", password: "Password123!" }
  end

  test "customer index uses page header table and status badges" do
    customer = create_customer!(display_name: "UX Customer Alpha", home_store: @store)

    get customers_customers_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Customers"
    assert_select ".ss-page-description", text: /Search customer profiles/
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"
    assert_select "label.ss-sr-only[for=?]", "q", text: "Search customers"
    assert_select ".ss-status-badge.status-active", text: "Active"
    assert_select "a[href='#{customers_customer_path(customer)}']", text: "View"
  end

  test "customer show separates lifecycle actions in page header" do
    customer = create_customer!(display_name: "UX Customer Show", home_store: @store)

    get customers_customer_path(customer)

    assert_response :success
    assert_select ".ss-detail-back .ss-btn-tertiary", text: /Back to Customers/
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Inactivate"
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select ".ss-status-badge.status-active", text: "Active"
    assert_select ".ss-empty-state__title", text: "No demand lines yet"
    assert_select ".ss-empty-state__title", text: "No contact events recorded"
  end

  test "customer forms use primary submit and tertiary cancel" do
    customer = create_customer!(display_name: "UX Customer Form", home_store: @store)

    get new_customers_customer_path
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Create Customer"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"

    get edit_customers_customer_path(customer)
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Save Changes"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"
  end
end
