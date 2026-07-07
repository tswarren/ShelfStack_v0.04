# frozen_string_literal: true

require "test_helper"

class ItemsAddItemUxContractTest < ActionDispatch::IntegrationTest
  include Phase3TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "add_item_ux", password: "Password123!")
    grant_permission!(@user, "items.access")
    grant_permission!(@user, "items.catalog_items.create")
    grant_permission!(@user, "items.products.create")
    grant_permission!(@user, "items.product_variants.create")
    grant_permission!(@user, "items.catalog_items.view")
    grant_permission!(@user, "items.external_lookup.access")
    grant_permission!(@user, "items.ingram_import.run")
    seed_phase3_reference_data!
    @format = create_format!(format_key: "add_item_ux_fmt", name: "UX Format", short_name: "UXF")
    @sub_department = create_sub_department!
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "add_item_ux", password: "Password123!" }
  end

  test "choose path step uses contract form footer" do
    get items_add_item_path(step: "choose_path")

    assert_response :success
    assert_select ".ss-page-header h1", text: "Add Item"
    footer = css_select("footer.ss-form-actions").first.to_s
    assert_operator footer.index("Continue"), :<, footer.index("Cancel")
    assert_select "footer.ss-form-actions button.ss-btn-primary", text: "Continue"
    assert_select "footer.ss-form-actions a.ss-btn-secondary", text: "Search for existing item"
    assert_select "footer.ss-form-actions a.ss-btn-tertiary", text: "Cancel"
  end

  test "identify step uses contract form footer" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }
    get items_add_item_path(step: "identify")

    assert_response :success
    assert_select ".ss-page-header h1", text: "Identify by ISBN"
    assert_select "footer.ss-form-actions button.ss-btn-primary", text: "Continue"
    assert_select "footer.ss-form-actions a.ss-btn-secondary", text: "Enter details manually"
    assert_select "footer.ss-form-actions a.ss-btn-tertiary", text: "Cancel"
  end

  test "item details step uses contract form footer" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }
    get items_add_item_path(step: "item_details")

    assert_response :success
    assert_select "footer.ss-form-actions button.ss-btn-primary", text: "Create Selling Setup"
    assert_select "footer.ss-form-actions button.ss-btn-secondary", text: "Done"
    assert_select "footer.ss-form-actions a.ss-btn-tertiary", text: "Cancel"
  end

  test "non-catalog selling setup uses contract form footer" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }
    get items_add_item_path(step: "selling_setup")

    assert_response :success
    assert_select ".ss-page-header h1", text: "Add Non-Catalog Item"
    assert_select "footer.ss-form-actions button.ss-btn-primary", text: "Add Sellable SKU"
    assert_select "footer.ss-form-actions button.ss-btn-secondary", text: "Done"
    assert_select "footer.ss-form-actions a.ss-btn-tertiary", text: "Cancel"
    assert_select ".ss-inline-actions button.ss-btn-secondary", text: "Generate SKU"
    assert_select ".ss-inline-actions a.ss-btn-link", text: "Back"
  end

  test "sellable sku step uses contract form footer and back link" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }
    post items_add_item_path(step: "selling_setup"), params: {
      product: {
        sku: "UX-MUG-001",
        name: "Wizard Mug",
        product_type: "financial",
        variation_type: "standard",
        list_price_cents: 1299,
        default_sub_department_id: @sub_department.id
      }
    }
    get items_add_item_path(step: "sellable_sku")

    assert_response :success
    assert_select "footer.ss-form-actions button.ss-btn-primary", text: "Create SKU"
    assert_select "footer.ss-form-actions button.ss-btn-secondary", text: "Create SKU and Add Another"
    assert_select "footer.ss-form-actions a.ss-btn-tertiary", text: "Cancel"
    assert_select "a.ss-btn-link", text: "Back"
  end

  test "ingram import uses contract form footer" do
    get items_ingram_import_path

    assert_response :success
    assert_select ".ss-detail-back .ss-btn-tertiary", text: /Back to Items/
    assert_select "footer.ss-form-actions button.ss-btn-primary", text: "Preview file"
    assert_select "footer.ss-form-actions a.ss-btn-tertiary", text: "Cancel"
  end
end
