# frozen_string_literal: true

require "test_helper"

class SetupPr4cSurfacesUxContractTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "pr4c_ux_admin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    %w[
      setup.category_schemes.view setup.category_schemes.create setup.category_schemes.update
      setup.category_schemes.inactivate setup.category_schemes.delete
      audit_events.view
      setup.product_vendors.view setup.product_vendors.inactivate setup.product_vendors.delete
      setup.inventory_locations.view setup.inventory_locations.create setup.inventory_locations.inactivate setup.inventory_locations.delete
      setup.bisac_subjects.view
    ].each { |key| grant_permission!(@admin, key) }
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "pr4c_ux_admin", password: "Password123!" }
  end

  test "category schemes index and show follow setup UX contract" do
    scheme = create_category_scheme!(name: "UX Scheme #{SecureRandom.hex(2)}")

    get setup_category_schemes_path
    assert_response :success
    assert_select ".ss-page-header h1", text: "Category Schemes"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"

    get setup_category_scheme_path(scheme)
    assert_response :success
    assert_select ".ss-detail-back .ss-btn-tertiary", text: /Back to Category Schemes/
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Manage Nodes"
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select "#category-scheme-danger-zone-heading", text: "Danger zone"
  end

  test "category nodes index keeps tree table and page header" do
    scheme = CategoryScheme.find_or_create_by!(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY) do |record|
      record.name = "Store Categories"
      record.purpose = CategoryNode::STORE_CATEGORIES_SCHEME_KEY
      record.active = true
    end
    scheme.category_nodes.create!(node_key: "ux_root", name: "UX Root", sort_order: 0, active: true)

    get setup_category_scheme_category_nodes_path(scheme)
    assert_response :success
    assert_select ".ss-page-header h1", text: "Store Categories"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"
    assert_select "table.ss-table--tree"
  end

  test "audit events index and show follow setup UX contract" do
    event = AuditEvent.order(:id).first
    assert event.present?, "expected at least one audit event from login"

    get setup_audit_events_path
    assert_response :success
    assert_select ".ss-page-header h1", text: "Audit Events"

    get setup_audit_event_path(event)
    assert_response :success
    assert_select ".ss-detail-back .ss-btn-tertiary", text: /Back to Audit Events/
    assert_select ".ss-page-header h1", text: event.event_name
  end

  test "product vendors show uses lifecycle header and danger zone" do
    product = create_product!
    vendor = create_vendor!
    product_vendor = ProductVendor.create!(product: product, vendor: vendor, active: true)

    get setup_product_vendor_path(product_vendor)
    assert_response :success
    assert_select ".ss-page-actions .ss-btn-primary", text: "Edit"
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Inactivate"
    assert_select "#product-vendor-danger-zone-heading", text: "Danger zone"
  end

  test "inventory locations index and show follow setup UX contract" do
    location = InventoryLocation.create!(
      store: @store,
      name: "UX Back Room",
      short_name: "UXBR",
      sort_order: 0,
      active: true
    )

    get setup_inventory_locations_path
    assert_response :success
    assert_select ".ss-page-header h1", text: "Inventory Locations"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"

    get setup_inventory_location_path(location)
    assert_response :success
    assert_select "#inventory-location-danger-zone-heading", text: "Danger zone"
  end

  test "bisac subjects show uses page header with import action" do
    get setup_bisac_subjects_path
    assert_response :success
    assert_select ".ss-page-header h1", text: "BISAC Subject Headings"
    assert_select ".ss-page-actions .ss-btn-primary", text: /Load \/ Update BISAC subjects/
  end

  test "inventory location forms use primary submit and tertiary cancel" do
    get new_setup_inventory_location_path
    assert_response :success
    assert_select ".ss-form-actions .ss-btn-primary", text: "Create Inventory Location"
    assert_select ".ss-form-actions .ss-btn-tertiary", text: "Cancel"
  end
end
