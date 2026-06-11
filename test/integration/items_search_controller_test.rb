# frozen_string_literal: true

require "test_helper"

class ItemsSearchControllerTest < ActionDispatch::IntegrationTest
  include Phase3TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "searchuser", password: "Password123!")
    grant_permission!(@user, "items.access")
    grant_permission!(@user, "items.catalog_items.view")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "searchuser", password: "Password123!" }
    @item = create_catalog_item!(title: "Searchable Book Title")
  end

  test "search returns matching item with lifecycle status" do
    get items_search_path, params: { q: "Searchable Book" }
    assert_response :success
    assert_match "Searchable Book Title", response.body
    assert_match "Catalog Only", response.body
  end

  test "search omits invalid identifier warning badge" do
    CatalogIdentifierService.add_identifier!(
      catalog_item: @item,
      identifier_type: "isbn13",
      value: "9780123456780",
      primary: false
    )

    get items_search_path, params: { q: @item.title }
    assert_response :success
    assert_no_match "Invalid Identifier Warning", response.body
    assert_match "Catalog Only", response.body
  end

  test "search shows variant summary price range and view item action only" do
    product = create_product!(catalog_item: @item)
    variant = create_product_variant!(product: product, selling_price_cents: 1899)

    get items_search_path, params: { q: @item.title }
    assert_response :success
    assert_match variant.condition.short_name, response.body
    assert_match "$18.99", response.body
    assert_match "View Item", response.body
    assert_no_match "Edit Catalog", response.body
    assert_no_match "Edit SKUs", response.body
    assert_no_match "Sell New", response.body
  end
end
