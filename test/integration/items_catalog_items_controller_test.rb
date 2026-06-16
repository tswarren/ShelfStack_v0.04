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

  test "create catalog item with isbn10 identifier" do
    assert_difference -> { CatalogItem.count }, 1 do
      post items_catalog_items_path, params: {
        catalog_item: {
          catalog_item_type: "book",
          title: "Created Book",
          format_id: @format.id,
          publication_status: "active",
          active: true,
          initial_identifier_type: "isbn10",
          initial_identifier_value: "0123456789"
        }
      }
    end

    item = CatalogItem.find_by!(title: "Created Book")
    assert_equal "9780123456786", item.primary_identifier.normalized_identifier
    assert AuditEvent.exists?(event_name: "catalog_item.created", auditable: item)
  end

  test "create without identifier is rejected" do
    assert_no_difference -> { CatalogItem.count } do
      post items_catalog_items_path, params: {
        catalog_item: {
          catalog_item_type: "book",
          title: "No Identifier",
          format_id: @format.id,
          publication_status: "active",
          active: true
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "update identifier from item catalog tab returns to item catalog tab" do
    item = create_catalog_item!(title: "Identifier Edit Book")
    identifier = item.primary_identifier

    patch update_identifier_items_catalog_item_path(item, identifier_id: identifier.id, return_to: "item"),
          params: { identifier_value: "9780306406157" }

    assert_redirected_to items_item_path(catalog_item_id: item.id, tab: "catalog")
    assert_equal "9780306406157", identifier.reload.normalized_identifier
  end

  test "destroy identifier from item catalog tab returns to item catalog tab" do
    item = create_catalog_item!(title: "Identifier Delete Book")
    primary = item.primary_identifier
    secondary = CatalogIdentifierService.add_identifier!(
      catalog_item: item,
      identifier_type: "publisher_number",
      value: "DELETE-ME",
      primary: false
    )

    delete destroy_identifier_items_catalog_item_path(item, identifier_id: secondary.id, return_to: "item")

    assert_redirected_to items_item_path(catalog_item_id: item.id, tab: "catalog")
    assert_not secondary.reload.active?
    assert primary.reload.primary_identifier?
  end

  test "add identifier from item catalog tab returns to item catalog tab" do
    item = create_catalog_item!(title: "Identifier Add Book")

    post add_identifier_items_catalog_item_path(item, return_to: "item"), params: {
      identifier_type: "publisher_number",
      identifier_value: "NEW-ID-99",
      primary: "0"
    }

    assert_redirected_to items_item_path(catalog_item_id: item.id, tab: "catalog")
    assert CatalogItemIdentifier.exists?(catalog_item: item, normalized_identifier: "NEWID99")
  end

  test "update catalog item with return_to item redirects to catalog tab" do
    item = create_catalog_item!(title: "Return Path Update Book")

    patch items_catalog_item_path(item, return_to: "item"), params: {
      catalog_item: {
        catalog_item_type: item.catalog_item_type,
        title: "Updated Return Path Title",
        format_id: item.format_id,
        publication_status: item.publication_status,
        active: true
      }
    }

    assert_redirected_to items_item_path(catalog_item_id: item.id, tab: "catalog")
    assert_equal "Updated Return Path Title", item.reload.title
  end

  test "inactivate catalog item with return_to item redirects to catalog tab" do
    item = create_catalog_item!(title: "Return Path Inactivate Book")

    patch inactivate_items_catalog_item_path(item, return_to: "item")

    assert_redirected_to items_item_path(catalog_item_id: item.id, tab: "catalog")
    assert_not item.reload.active?
  end

  test "create catalog item with structured bisac selections" do
    seed_bisac_scheme!
    general = CategoryNode.find_by!(node_key: "fic000000")

    assert_difference -> { CatalogItem.count }, 1 do
      post items_catalog_items_path, params: {
        primary_bisac_category_node_id: general.id,
        catalog_item: {
          catalog_item_type: "book",
          title: "BISAC Linked Book",
          format_id: @format.id,
          publication_status: "active",
          active: true,
          initial_identifier_type: "isbn13",
          initial_identifier_value: "9780143127741"
        }
      }
    end

    item = CatalogItem.find_by!(title: "BISAC Linked Book")
    assert_equal general.id, item.primary_bisac_categorization.category_node_id
    assert_includes item.bisac_subjects, "Fiction / General [bisac/FIC000000]"
  end
end
