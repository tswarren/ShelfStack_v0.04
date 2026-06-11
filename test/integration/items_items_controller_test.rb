# frozen_string_literal: true

require "test_helper"

class ItemsItemsControllerTest < ActionDispatch::IntegrationTest
  include Phase3TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "detailuser", password: "Password123!")
    grant_permission!(@user, "items.access")
    grant_permission!(@user, "items.catalog_items.view")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "detailuser", password: "Password123!" }
    @product = create_product!
    @variant = create_product_variant!(product: @product)
  end

  test "unified item detail shows catalog layout on overview" do
    get items_item_path(catalog_item_id: @product.catalog_item.id)
    assert_response :success
    assert_match @product.catalog_item.title, response.body
    assert_match "Location &amp; Availability", response.body
    assert_match @variant.sku, response.body
    assert_match "Stock", response.body
    assert_no_match "ss-item-edit-link", response.body
    assert_no_match "Edit Catalog Item", response.body
    assert_no_match "Edit Product", response.body
    assert_no_match "ss-context-actions", response.body
    assert_no_match "ss-item-footer-actions", response.body
    assert_match "Sellable", response.body
  end

  test "overview shows cover image when product has attachment" do
    @product.cover_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/cover.png")),
      filename: "cover.png",
      content_type: "image/png"
    )

    get items_item_path(catalog_item_id: @product.catalog_item.id)
    assert_response :success
    assert_match "ss-item-cover-image", response.body
  end

  test "overview shows display location eyebrow with parent breadcrumbs" do
    store_floor = create_display_location!(name: "Store Floor", short_name: "Flr #{SecureRandom.hex(2)}")
    fiction = create_display_location!(name: "Fiction", short_name: "Fic #{SecureRandom.hex(2)}", parent: store_floor)
    shelf = create_display_location!(name: "Shelf A", short_name: "ShA #{SecureRandom.hex(2)}", parent: fiction)
    @product.update!(default_display_location: shelf)

    get items_item_path(catalog_item_id: @product.catalog_item.id)
    assert_response :success
    assert_match "ss-item-location-eyebrow", response.body
    assert_match "Store Floor", response.body
    assert_match "Fiction", response.body
    assert_match "Shelf A", response.body
  end

  test "selling tab shows variant matrix and selling actions" do
    get items_item_path(catalog_item_id: @product.catalog_item.id, tab: "selling")
    assert_response :success
    assert_match @variant.sku, response.body
    assert_match edit_items_product_path(@product), response.body
    assert_match new_items_product_variant_path(product_id: @product.id), response.body
    assert_match "Edit product", response.body
    assert_match "New sellable SKUs", response.body
    assert_no_match "ss-context-actions", response.body
  end

  test "detail breadcrumbs show catalog product and variant chain" do
    get items_item_path(catalog_item_id: @product.catalog_item.id)
    assert_response :success
    assert_match "Catalog: #{@product.catalog_item.title}", response.body
    assert_match "Product: #{@product.name}", response.body
    assert_match "Variants:", response.body
  end

  test "catalog tab shows primary badge and identifier row actions" do
    grant_permission!(@user, "items.catalog_items.update")
    primary = @product.catalog_item.primary_identifier
    secondary = CatalogIdentifierService.add_identifier!(
      catalog_item: @product.catalog_item,
      identifier_type: "publisher_number",
      value: "ALT-ROW-ID",
      primary: false
    )

    get items_item_path(catalog_item_id: @product.catalog_item.id, tab: "catalog")
    assert_response :success
    assert_match "ss-status-badge status-active\">Primary", response.body
    assert_no_match "<th>Primary</th>", response.body
    assert_no_match "<th>Valid</th>", response.body
    assert_match "edit_identifier?identifier_id=#{primary.id}", response.body
    assert_match "destroy_identifier?identifier_id=#{secondary.id}", response.body
    assert_match "Edit catalog details", response.body
    assert_match "Add identifier", response.body
    assert_match "new_identifier", response.body
    assert_no_match "ss-context-actions", response.body
  end

  test "catalog tab shows invalid identifier badge on invalid barcodes" do
    grant_permission!(@user, "items.catalog_items.update")
    CatalogIdentifierService.add_identifier!(
      catalog_item: @product.catalog_item,
      identifier_type: "isbn13",
      value: "9780123456780",
      primary: false
    )

    get items_item_path(catalog_item_id: @product.catalog_item.id, tab: "catalog")
    assert_response :success
    assert_match "Invalid identifier", response.body
    assert_no_match "Invalid Identifier Warning", response.body
  end

  test "catalog tab lists primary identifier before other identifiers" do
    grant_permission!(@user, "items.catalog_items.update")
    primary = @product.catalog_item.primary_identifier
    secondary = CatalogIdentifierService.add_identifier!(
      catalog_item: @product.catalog_item,
      identifier_type: "publisher_number",
      value: "SECONDARY-ID",
      primary: false
    )

    get items_item_path(catalog_item_id: @product.catalog_item.id, tab: "catalog")
    assert_response :success

    primary_pos = response.body.index("identifier_id=#{primary.id}")
    secondary_pos = response.body.index("identifier_id=#{secondary.id}")
    assert primary_pos < secondary_pos
  end

  test "display tab shows variant display locations and setup vendor link" do
    get items_item_path(catalog_item_id: @product.catalog_item.id, tab: "display")
    assert_response :success
    assert_match "Variant display locations", response.body
    assert_match @variant.sku, response.body
    assert_match setup_vendors_path, response.body
    assert_match edit_items_product_path(@product, anchor: "product_default_display_location_id"), response.body
    assert_match edit_items_product_variant_path(@variant), response.body
  end
end
