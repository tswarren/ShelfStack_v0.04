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
    @product = create_legacy_catalog_linked_product!
    @product.update!(bisac_subjects: "Fiction / General [bisac/FIC000000]")
    @variant = create_product_variant!(product: @product)
  end

  def item_path(**params)
    items_item_path({ product_id: @product.id }.merge(params))
  end

  test "unified item detail shows catalog layout on overview" do
    get item_path
    assert_response :success
    assert_match @product.title, response.body
    assert_no_match "Location &amp; Availability", response.body
    assert_match @variant.sku, response.body
    assert_match "Sellable SKUs", response.body
    assert_match "ss-item-subject-list", response.body
    assert_match ">Subjects<", response.body
    assert_match 'id="variant-matrix"', response.body
    assert_match "ss-item-table", response.body
    assert_no_match "ss-item-subject-chip", response.body
    assert_no_match "ss-item-edit-link", response.body
    assert_no_match "Edit Catalog Item", response.body
    assert_no_match "Edit Product", response.body
    assert_no_match "ss-context-actions", response.body
    assert_no_match "ss-item-footer-actions", response.body
    assert_no_match "ss-breadcrumbs", response.body
    assert_match "Sellable", response.body
    assert_match "Item setup", response.body
    assert_match "Operations", response.body
  end

  test "overview shows cover image when product has attachment" do
    @product.cover_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/cover.png")),
      filename: "cover.png",
      content_type: "image/png"
    )

    get item_path
    assert_response :success
    assert_match "ss-item-cover-image", response.body
  end

  test "overview shows display location eyebrow with parent breadcrumbs" do
    store_floor = create_display_location!(name: "Store Floor", short_name: "Flr #{SecureRandom.hex(2)}")
    fiction = create_display_location!(name: "Fiction", short_name: "Fic #{SecureRandom.hex(2)}", parent: store_floor)
    shelf = create_display_location!(name: "Shelf A", short_name: "ShA #{SecureRandom.hex(2)}", parent: fiction)
    @product.update!(default_display_location: shelf)

    get item_path
    assert_response :success
    assert_match "ss-item-location-eyebrow", response.body
    assert_match "Store Floor", response.body
    assert_match "Fiction", response.body
    assert_match "Shelf A", response.body
  end

  test "overview eyebrow shows store category after display location" do
    store_floor = create_display_location!(name: "Store Floor", short_name: "Flr #{SecureRandom.hex(2)}")
    shelf = create_display_location!(name: "Shelf A", short_name: "ShA #{SecureRandom.hex(2)}", parent: store_floor)
    scheme = CategoryScheme.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY) ||
             create_category_scheme!(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY, name: "Store Sections")
    biography = create_category_node!(category_scheme: scheme, node_key: "biography", name: "Biography")
    @product.update!(default_display_location: shelf, store_category: biography)

    get item_path
    assert_response :success

    eyebrow = response.body[/ss-item-location-eyebrow.*?<\/nav>/m]
    assert_includes eyebrow, "Store Floor"
    assert_includes eyebrow, "Shelf A"
    assert_includes eyebrow, "Biography"
    assert_operator eyebrow.index("Shelf A"), :<, eyebrow.index("Biography")
  end

  test "item setup tab shows variant matrix and selling actions" do
    get item_path(tab: "item_setup")
    assert_response :success
    assert_match "Item metadata", response.body
    assert_match "Product setup", response.body
    assert_match "Display and vendor sourcing", response.body
    assert_match @variant.sku, response.body
    assert_match edit_items_product_path(@product, return_to: "item"), response.body
    assert_match "product_variants/new?product_id=#{@product.id}", response.body
    assert_match "return_to=item", response.body
    assert_match edit_items_product_variant_path(@variant, return_to: "item"), response.body
    assert_match "Edit product", response.body
    assert_match "New sellable SKUs", response.body
    assert_no_match "ss-context-actions", response.body
  end

  test "item setup tab highlights variant row when variant_id param present" do
    get item_path(
      tab: "item_setup",
      variant_id: @variant.id
    )

    assert_response :success
    assert_match "ss-table-row--highlight", response.body
  end

  test "item setup tab shows primary badge and identifier row actions" do
    grant_permission!(@user, "items.catalog_items.update")
    primary = @product.primary_identifier
    secondary = ProductIdentifierService.add_identifier_for_legacy_type!(
      product: @product,
      identifier_type: "publisher_number",
      value: "ALT-ROW-ID",
      primary: false
    )

    get item_path(tab: "item_setup")
    assert_response :success
    assert_match "ss-status-badge status-active\">Primary", response.body
    assert_no_match "<th>Primary</th>", response.body
    assert_no_match "<th>Valid</th>", response.body
    assert_match items_setup_modals_identifier_path(primary, product_id: @product.id), response.body
    assert_match "Quick edit", response.body
    assert_match "Edit bibliographic details", response.body
    assert_match "Quick add identifier", response.body
    assert_match edit_items_catalog_item_path(@product.catalog_item, return_to: "item"), response.body
    assert_match "Inactivate catalog item", response.body
    assert_match "Generate house EAN (201)", response.body
    assert_no_match "ss-context-actions", response.body
  end

  test "item setup tab shows invalid identifier badge on invalid barcodes" do
    grant_permission!(@user, "items.catalog_items.update")
    ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "gtin",
      value: "9780123456780",
      primary: false
    )

    get item_path(tab: "item_setup")
    assert_response :success
    assert_match "Invalid identifier", response.body
    assert_no_match "Invalid Identifier Warning", response.body
  end

  test "item setup tab shows bibliographic edit for fused product without catalog item" do
    grant_permission!(@user, "items.products.update")
    fused_product = create_product!(
      skip_product_identifier: true,
      title: "Fused Only Book",
      catalog_item_type: "book",
      publication_status: "active"
    )
    create_product_variant!(product: fused_product)

    get items_item_path(product_id: fused_product.id, tab: "item_setup")

    assert_response :success
    assert_match "Edit bibliographic details", response.body
    assert_match edit_metadata_items_product_path(fused_product, return_to: "item"), response.body
  end

  test "item setup tab lists primary identifier before other identifiers" do
    grant_permission!(@user, "items.catalog_items.update")
    primary = @product.primary_identifier
    secondary = ProductIdentifierService.add_identifier_for_legacy_type!(
      product: @product,
      identifier_type: "publisher_number",
      value: "SECONDARY-ID",
      primary: false
    )

    get item_path(tab: "item_setup")
    assert_response :success

    primary_pos = response.body.index(primary.normalized_identifier)
    secondary_pos = response.body.index(secondary.normalized_identifier)
    assert primary_pos < secondary_pos
  end

  test "item setup tab shows variant display locations and product vendor sourcing links" do
    grant_permission!(@user, "setup.product_vendors.create", store: @store)
    grant_permission!(@user, "setup.product_variant_vendors.create", store: @store)

    get item_path(tab: "item_setup")
    assert_response :success
    assert_match "Variant display locations", response.body
    assert_match @variant.sku, response.body
    assert_match "No product vendor sourcing records yet", response.body
    assert_match new_items_product_product_vendor_path(@product), response.body
    assert_match edit_items_product_path(@product, anchor: "product_default_display_location_id"), response.body
    assert_match edit_items_product_variant_path(@variant), response.body
  end

  test "operations tab renders variant summary and drawer entry point" do
    get item_path(tab: "operations")
    assert_response :success
    assert_match "Variant operations", response.body
    assert_match @variant.sku, response.body
    assert_match "Details", response.body
    assert_match "demand, purchasing, receiving", response.body
    assert_includes response.body, 'id="item-variant-ops-drawer"'
    assert_includes response.body, "Receiving history"
  end

  test "activity tab renders document trail and collapsed audit timeline" do
    seed_phase5_reference_data!
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.ledger.view", store: @store)
    PurchaseRequest.create!(store: @store, status: "open").purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 1,
      status: "open"
    )

    get item_path(tab: "activity")
    assert_response :success
    assert_match "TBO #", response.body
    assert_match "Audit timeline", response.body
    assert_match "ss-collapsible-panel", response.body
  end

  test "overview shows attention panel when open tbo exists" do
    seed_phase5_reference_data!
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
    PurchaseRequest.create!(store: @store, status: "open").purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 2,
      status: "open"
    )

    get item_path(tab: "overview")
    assert_response :success
    assert_match "Needs Attention", response.body
    assert_match "open TBO", response.body
  end

  test "legacy catalog_item_id redirects to product_id when product linked" do
    get items_item_path(catalog_item_id: @product.catalog_item.id)
    assert_redirected_to items_item_path(product_id: @product.id)
  end

  test "catalog-only shell loads and prompts for product creation" do
    catalog_only = create_catalog_item!(title: "Bibliographic Shell Only")
    get items_item_path(catalog_item_id: catalog_only.id, tab: "item_setup")
    assert_response :success
    assert_match "Create a product", response.body
  end

  test "operations tab omits overview summary cards and metric strip" do
    seed_phase5_reference_data!
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)

    get item_path(tab: "operations")

    assert_response :success
    assert_match "Variant operations", response.body
    assert_no_match "ss-item-summary-cards", response.body
    assert_no_match "ss-metric-strip", response.body
  end
end
