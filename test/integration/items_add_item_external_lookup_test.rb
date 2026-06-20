# frozen_string_literal: true

require "test_helper"

class ItemsAddItemExternalLookupTest < ActionDispatch::IntegrationTest
  include Phase3TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "lookupuser", password: "Password123!")
    grant_permission!(@user, "items.access")
    grant_permission!(@user, "items.catalog_items.create")
    grant_permission!(@user, "items.products.create")
    grant_permission!(@user, "items.product_variants.create")
    grant_external_lookup_permissions!(@user)
    create_isbndb_source!
    @format = create_format!(format_key: "trade_paperback", name: "Trade Paperback", short_name: "TP")
    seed_phase3_reference_data!
    @sub_department = create_sub_department!
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "lookupuser", password: "Password123!" }
  end

  test "catalog linked path redirects to identify step" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }
    assert_redirected_to items_add_item_path(step: "identify")
  end

  test "isbn lookup import stages item details then saves on submit" do
    payload = isbndb_fixture("success")
    client = stub_isbndb_client(isbndb_response(status_code: 200, body: payload))

    original_new = ExternalCatalog::Provider::IsbndbClient.method(:new)
    ExternalCatalog::Provider::IsbndbClient.singleton_class.define_method(:new) { |**_| client }
    begin
      post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }
      post items_external_lookup_path, params: { isbn: Phase65TestHelper::ISBNDB_SUCCESS_ISBN }
    ensure
      ExternalCatalog::Provider::IsbndbClient.singleton_class.define_method(:new, original_new)
    end

    assert_response :redirect
    follow_redirect!
    assert_response :success

    assert_no_difference -> { CatalogItem.count } do
      post items_external_lookup_import_path(ExternalLookupResult.last), params: { action_type: "create_catalog_item" }
    end

    assert_redirected_to items_add_item_path(step: "item_details")
    follow_redirect!
    assert_match(/Great Gatsby/, response.body)
    assert_select "textarea[name='catalog_item[creators]']" do |elements|
      assert_includes elements.first.content, "Fitzgerald, F. Scott [author]"
    end
    assert_select "textarea[name='catalog_item[themes]']" do |elements|
      assert_includes elements.first.content, "Fiction; Classics"
    end

    assert_difference -> { CatalogItem.count }, 1 do
      assert_difference -> { ExternalCatalogImport.count }, 1 do
        post items_add_item_path(step: "item_details"), params: {
          catalog_item: {
            title: "Edited Great Gatsby",
            catalog_item_type: "book",
            format_id: @format.id
          },
          commit: "Create Selling Setup"
        }
      end
    end

    item = CatalogItem.find_by!(title: "Edited Great Gatsby")
    assert item.catalog_item_identifiers.active_records.exists?(identifier_type: "isbn13", normalized_identifier: Phase65TestHelper::ISBNDB_SUCCESS_ISBN)
    assert_redirected_to items_add_item_path(step: "selling_setup")

    follow_redirect!
    assert_select "input[name='product[list_price_cents]'][value='1700']"

    cover_attached = false
    original_call = ExternalCatalog::CoverImageImporter.method(:call)
    ExternalCatalog::CoverImageImporter.singleton_class.define_method(:call) do |**_args|
      cover_attached = true
      ExternalCatalog::CoverImageImporter::Result.new(attached: true, message: nil)
    end
    begin
      post items_add_item_path(step: "selling_setup"), params: {
        product: {
          list_price_cents: 2000,
          default_sub_department_id: @sub_department.id
        }
      }
    ensure
      ExternalCatalog::CoverImageImporter.singleton_class.define_method(:call, original_call)
    end

    assert cover_attached
    assert_redirected_to items_add_item_path(step: "sellable_sku")
  end

  test "lookup denied without search permission" do
    user = create_user!(username: "nosearch", password: "Password123!")
    grant_permission!(user, "items.access")
    grant_permission!(user, "items.external_lookup.access")
    delete logout_path
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "nosearch", password: "Password123!" }

    post items_external_lookup_path, params: { isbn: Phase65TestHelper::ISBNDB_SUCCESS_ISBN }
    assert_redirected_to root_path
  end
end
