# frozen_string_literal: true

require "test_helper"

class ItemsExternalMetadataControllerTest < ActionDispatch::IntegrationTest
  include Phase3TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "metadataser", password: "Password123!")
    grant_permission!(@user, "items.access")
    grant_permission!(@user, "items.catalog_items.view")
    grant_permission!(@user, "items.external_lookup.access")
    grant_permission!(@user, "items.external_lookup.view_raw_payload")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "metadataser", password: "Password123!" }

    @product = create_legacy_catalog_linked_product!
    @catalog_item = @product.catalog_item
    @source = create_isbndb_source!
    @lookup_result = persist_lookup_result!
    @import = ExternalCatalogImport.create!(
      external_lookup_result: @lookup_result,
      external_data_source: @source,
      status: "applied",
      action_type: "create_catalog_item",
      imported_by_user: @user,
      catalog_item: @catalog_item,
      product: @product,
      field_mapping_snapshot: { "title" => @lookup_result.title },
      raw_payload_json: @lookup_result.raw_payload_json,
      applied_at: Time.current
    )
  end

  test "shows original metadata for imported catalog item" do
    get items_item_external_metadata_path(catalog_item_id: @catalog_item.id)

    assert_response :success
    assert_match @lookup_result.title, response.body
    assert_match "Raw Provider Payload", response.body
    assert_match "The Great Gatsby", response.body
    assert_match "Back to item setup", response.body
  end

  test "redirects when catalog item has no external import" do
    @import.destroy!

    get items_item_external_metadata_path(catalog_item_id: @catalog_item.id)

    assert_redirected_to items_item_path(product_id: @product.id, tab: "item_setup")
    assert_equal "No external catalog metadata is linked to this item.", flash[:alert]
  end

  test "denies access without external lookup permission" do
    delete logout_path
    user = create_user!(username: "nometadata", password: "Password123!")
    grant_permission!(user, "items.access")
    grant_permission!(user, "items.catalog_items.view")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "nometadata", password: "Password123!" }

    get items_item_external_metadata_path(catalog_item_id: @catalog_item.id)

    assert_redirected_to root_path
  end

  test "item setup tab shows link when external import exists" do
    get items_item_path(product_id: @product.id, tab: "item_setup")

    assert_response :success
    assert_match items_item_external_metadata_path(catalog_item_id: @catalog_item.id), response.body
    assert_match "View original metadata", response.body
  end

  test "item setup tab hides link when no external import exists" do
    @import.destroy!

    get items_item_path(product_id: @product.id, tab: "item_setup")

    assert_response :success
    assert_no_match "View original metadata", response.body
  end

  private

  def persist_lookup_result!
    payload = isbndb_fixture("success")
    candidate = ExternalCatalog::Provider::IsbndbNormalizer.call(payload: payload)
    persisted = ExternalCatalog::PersistLookupResult.call(
      source: @source,
      actor: @user,
      query: candidate.isbn13,
      normalized_query: candidate.isbn13,
      lookup_type: "isbn",
      request_path: "/book/#{candidate.isbn13}",
      status: "completed",
      response_status_code: 200,
      candidate: candidate
    )
    persisted.lookup_result
  end
end
