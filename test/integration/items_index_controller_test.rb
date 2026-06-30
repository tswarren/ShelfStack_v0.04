# frozen_string_literal: true

require "test_helper"

class ItemsIndexControllerTest < ActionDispatch::IntegrationTest
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
    @product = create_product!(catalog_item: @item)
  end

  test "browse without query returns index table" do
    get items_root_path

    assert_response :success
    assert_match "Items", response.body
    assert_match "Add Item", response.body
    assert_match "View Item", response.body
    assert_match items_item_path(product_id: @product.id), response.body
  end

  test "search returns matching item with lifecycle status" do
    get items_root_path, params: { q: "Searchable Book" }
    assert_response :success
    assert_match "Searchable Book Title", response.body
    assert_match "Product Created", response.body
  end

  test "search omits invalid identifier warning badge" do
    add_test_product_identifier!(
      catalog_item: @item,
      identifier_type: "isbn13",
      value: "9780123456780",
      primary: false
    )

    get items_root_path, params: { q: @item.title }
    assert_response :success
    assert_no_match "Invalid Identifier Warning", response.body
    assert_match "Product Created", response.body
  end

  test "search shows variant summary price range and view item action only" do
    variant = create_product_variant!(product: @product, selling_price_cents: 1899)

    get items_root_path, params: { q: @item.title }
    assert_response :success
    assert_match variant.condition.short_name, response.body
    assert_match "$18.99", response.body
    assert_match "View Item", response.body
    assert_no_match "Edit Catalog", response.body
    assert_no_match "Edit SKUs", response.body
    assert_no_match "Sell New", response.body
  end

  test "index renders resolved product cover image in search results" do
    @product.cover_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/cover.png")),
      filename: "product-cover.png",
      content_type: "image/png"
    )

    get items_root_path, params: { q: @item.title }

    assert_response :success
    assert_match "ss-item-cover-image--search", response.body
  end

  test "index shows stock and orders column when inventory permissions granted" do
    seed_phase5_reference_data!
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
    variant = create_product_variant!(product: @product, selling_price_cents: 1899)
    InventoryBalance.create!(
      store: @store,
      product_variant: variant,
      quantity_on_hand: 5,
      quantity_available: 5
    )

    get items_root_path, params: { q: @item.title }
    assert_response :success
    assert_match "Signals", response.body
    assert_match "Avail. 5", response.body
    assert_match "TBO", response.body
    assert_match ">View<", response.body
  end

  test "filter by format narrows results" do
    hardcover = @item.format
    other_format = create_format!(format_key: "filter_fmt", name: "Filter Format Test")
    matching = create_catalog_item!(title: "Hardcover Only Item", format: hardcover)
    create_product!(catalog_item: matching)
    create_catalog_item!(title: "Other Format Book", format: other_format)

    get items_root_path, params: { format_id: hardcover.id, q: "Searchable" }
    assert_response :success
    assert_match "Searchable Book Title", response.body
    assert_no_match "Other Format Book", response.body
  end

  test "legacy search path redirects to items index with params" do
    get items_search_path, params: { q: "Searchable Book" }

    assert_redirected_to items_root_path(q: "Searchable Book")
  end
end
