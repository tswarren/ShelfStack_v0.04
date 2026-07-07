# frozen_string_literal: true

require "test_helper"

class OrdersUxContractTest < ActionDispatch::IntegrationTest
  include Phase5TestHelper
  include Phase7aTestHelper

  setup do
    seed_phase3_reference_data!
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "demand.access", store: @store)
    login_user!(@user, workstation: @workstation)

    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    ProductVendor.create!(product: @variant.product, vendor: @vendor, active: true, preferred: true)
  end

  test "purchase order index uses page header and primary new action" do
    get orders_purchase_orders_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Purchase Orders"
    page_actions = css_select(".ss-page-actions").first.to_s
    assert_operator page_actions.index("Manual TBO"), :<, page_actions.index("New")
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Manual TBO"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"
  end

  test "draft purchase order show separates edit and submit actions" do
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 2) ]
    )

    get orders_purchase_order_path(order)

    assert_response :success
    assert_select ".ss-document-header .ss-page-actions .ss-btn-secondary", text: "Edit"
    assert_select ".ss-document-header .ss-page-actions .ss-btn-primary", text: "Submit"
    page_actions = css_select(".ss-document-header .ss-page-actions").first.to_s
    assert_operator page_actions.index("Edit"), :<, page_actions.index("Submit")
    assert_select ".ss-detail-actions", count: 0
  end

  test "receipt index uses page header" do
    get orders_receipts_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Receipts"
    page_actions = css_select(".ss-page-actions").first.to_s
    assert_operator page_actions.index("Vendor shipment"), :<, page_actions.index("New")
    assert_select ".ss-page-actions .ss-btn-secondary", text: "Vendor shipment"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New"
  end

  test "buyer workbench bulk actions use contract buttons when rows exist" do
    DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: create_customer!,
      quantity: 1
    )

    get orders_buyer_workbench_path(tab: "needs_ordering")

    assert_response :success
    assert_select "footer.ss-form-actions .ss-btn-primary", text: "Create PO from selected"
    assert_select "footer.ss-form-actions .ss-btn-secondary", text: "Add to existing draft PO"
  end
end
