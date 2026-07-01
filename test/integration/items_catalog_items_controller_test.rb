# frozen_string_literal: true

require "test_helper"

class ItemsCatalogItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "itemsadmin", password: "Password123!")
    grant_permission!(@admin, "items.access")
    %w[
      items.catalog_items.view items.catalog_items.create items.catalog_items.update
      items.catalog_items.inactivate items.catalog_items.reactivate items.catalog_items.delete
    ].each { |key| grant_permission!(@admin, key) }
    @format = create_format!(format_key: "ctrl_test", name: "Control Test", short_name: "Ctrl")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "itemsadmin", password: "Password123!" }
  end

  test "create catalog item without requiring identifier" do
    assert_difference -> { CatalogItem.count }, 1 do
      post items_catalog_items_path, params: {
        catalog_item: {
          catalog_item_type: "book",
          title: "Created Book",
          format_id: @format.id,
          publication_status: "active",
          active: true
        }
      }
    end

    item = CatalogItem.find_by!(title: "Created Book")
    assert_nil item.primary_identifier
    assert AuditEvent.exists?(event_name: "catalog_item.created", auditable: item)
  end

  test "create catalog item with initial identifier bootstraps product and product identifier" do
    grant_permission!(@admin, "items.products.create")

    assert_difference [ -> { CatalogItem.count }, -> { Product.count } ], 1 do
      post items_catalog_items_path, params: {
        catalog_item: {
          catalog_item_type: "book",
          title: "ISBN Bootstrap Book",
          format_id: @format.id,
          publication_status: "active",
          active: true,
          initial_identifier_type: "isbn13",
          initial_identifier_value: "9780306406157"
        }
      }
    end

    item = CatalogItem.find_by!(title: "ISBN Bootstrap Book")
    product = item.products.active_records.order(:id).first
    assert_not_nil product
    assert_equal "9780306406157", product.sku
    assert_equal "9780306406157", product.primary_identifier.normalized_identifier
    assert_redirected_to items_item_path(product_id: product.id, tab: "item_setup")
    assert AuditEvent.exists?(event_name: "product.created", auditable: product)
  end

  test "update identifier from item catalog tab returns to item catalog tab" do
    item = create_catalog_item!(title: "Identifier Edit Book")
    product = create_legacy_catalog_linked_product!(catalog_item: item, skip_product_identifier: true)
    identifier = ProductIdentifierService.add_identifier!(
      product: product,
      validation_family: "gtin",
      value: "9780123456789",
      primary: true
    )

    patch update_identifier_items_catalog_item_path(item, identifier_id: identifier.id, return_to: "item"),
          params: { identifier_value: "9780306406157" }

    assert_redirected_to items_item_path(product_id: product.id, tab: "item_setup")
    assert_equal "9780306406157", identifier.reload.normalized_identifier
  end

  test "destroy identifier from item catalog tab returns to item catalog tab" do
    item = create_catalog_item!(title: "Identifier Delete Book")
    product = create_legacy_catalog_linked_product!(catalog_item: item)
    primary = product.primary_identifier
    secondary = ProductIdentifierService.add_identifier_for_legacy_type!(
      product: product,
      identifier_type: "publisher_number",
      value: "DELETE-ME",
      primary: false
    )

    delete destroy_identifier_items_catalog_item_path(item, identifier_id: secondary.id, return_to: "item")

    assert_redirected_to items_item_path(product_id: product.id, tab: "item_setup")
    assert_not secondary.reload.active?
    assert primary.reload.primary_identifier?
  end

  test "add identifier from item catalog tab returns to item catalog tab" do
    item = create_catalog_item!(title: "Identifier Add Book")
    product = create_legacy_catalog_linked_product!(catalog_item: item)

    post add_identifier_items_catalog_item_path(item, return_to: "item"), params: {
      identifier_type: "publisher_number",
      identifier_value: "NEW-ID-99",
      primary: "0"
    }

    assert_redirected_to items_item_path(product_id: product.id, tab: "item_setup")
    assert ProductIdentifier.exists?(product: product, normalized_identifier: "NEWID99")
  end

  test "update catalog item with return_to item redirects to catalog tab" do
    item = create_catalog_item!(title: "Return Path Update Book")

    patch items_catalog_item_path(item, return_to: "item"), params: {
      catalog_item: {
        title: "Return Path Updated"
      }
    }

    assert_redirected_to items_item_path(catalog_item_id: item.id, tab: "item_setup")
    assert_equal "Return Path Updated", item.reload.title
  end
end
