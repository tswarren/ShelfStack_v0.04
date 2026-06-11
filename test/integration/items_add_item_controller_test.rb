# frozen_string_literal: true

require "test_helper"

class ItemsAddItemControllerTest < ActionDispatch::IntegrationTest
  include Phase3TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "wizarduser", password: "Password123!")
    grant_permission!(@user, "items.access")
    grant_permission!(@user, "items.catalog_items.create")
    grant_permission!(@user, "items.products.create")
    grant_permission!(@user, "items.product_variants.create")
    grant_permission!(@user, "items.catalog_items.view")
    @format = create_format!(format_key: "wizard_fmt", name: "Wizard Format", short_name: "WF")
    create_category!
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "wizarduser", password: "Password123!" }
  end

  test "add item wizard creates catalog product and variant then redirects to detail" do
    get items_new_add_item_path
    assert_redirected_to items_add_item_path(step: "identify")

    post items_add_item_path(step: "identify"), params: { create_new: "Create New Item", q: "" }
    assert_redirected_to items_add_item_path(step: "type")

    post items_add_item_path(step: "type"), params: { catalog_item_type: "book" }
    assert_redirected_to items_add_item_path(step: "catalog_details")

    assert_difference [-> { CatalogItem.count }, -> { Product.count }, -> { ProductVariant.count }], 1 do
      post items_add_item_path(step: "catalog_details"), params: {
        catalog_item: {
          title: "Wizard Book",
          catalog_item_type: "book",
          format_id: @format.id,
          creators: "Test Author"
        }
      }
      assert_redirected_to items_add_item_path(step: "selling_setup")

      post items_add_item_path(step: "selling_setup"), params: {
        product: { list_price_cents: 1899 }
      }
      assert_redirected_to items_add_item_path(step: "sellable_sku")

      post items_add_item_path(step: "sellable_sku"), params: {
        product_variant: { selling_price_cents: 1899 }
      }
    end

    item = CatalogItem.find_by!(title: "Wizard Book")
    assert_redirected_to items_item_path(catalog_item_id: item.id)
  end
end
