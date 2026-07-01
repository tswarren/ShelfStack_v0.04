# frozen_string_literal: true

require "test_helper"

class ExternalCatalogImportFlowTest < ActiveSupport::TestCase
  include Phase3TestHelper

  setup do
    @user = create_user!
    @source = create_isbndb_source!
    @paperback = create_format!(format_key: "trade_paperback", name: "Trade Paperback", short_name: "TP")
    @lookup_result = persist_lookup_result_from_fixture!("success")
  end

  test "import preview requires manual format selection when binding is unmapped" do
    result = persist_lookup_result_from_fixture!("ambiguous_binding")
    preview = ExternalCatalog::ImportPreview.call(lookup_result: result)

    assert preview.format_required
    assert_not preview.apply_blocked
    assert_includes preview.allowed_actions, "create_catalog_item"
    assert_includes preview.allowed_actions, "skip"
  end

  test "create import with selected format stages item details when binding is unmapped" do
    result = persist_lookup_result_from_fixture!("ambiguous_binding")

    import_result = ExternalCatalog::ImportCandidate.call(
      lookup_result: result,
      action_type: "create_catalog_item",
      actor: @user,
      format_id: @paperback.id
    )

    assert_equal :staged, import_result.status
    assert_equal @paperback, import_result.format
  end

  test "create import without format fails when binding is unmapped" do
    result = persist_lookup_result_from_fixture!("ambiguous_binding")

    import_result = ExternalCatalog::ImportCandidate.call(
      lookup_result: result,
      action_type: "create_catalog_item",
      actor: @user
    )

    assert_equal :failed, import_result.status
    assert_includes import_result.message, "Select a format"
  end

  test "create import stages item details without persisting catalog item" do
    assert_no_difference -> { CatalogItem.count } do
      assert_no_difference -> { ExternalCatalogImport.count } do
        @import_result = ExternalCatalog::ImportCandidate.call(
          lookup_result: @lookup_result,
          action_type: "create_catalog_item",
          actor: @user
        )
      end
    end

    assert_equal :staged, @import_result.status
    assert_nil @import_result.catalog_item
  end

  test "finalize create records import after item details save" do
    product = Product.create!(
      title: "Edited Gatsby",
      catalog_item_type: "book",
      format: @paperback,
      publication_status: "active",
      active: true,
      product_type: "physical",
      variation_type: "conditional",
      sku: Phase65TestHelper::ISBNDB_SUCCESS_ISBN,
      name: "Edited Gatsby"
    )

    assert_difference -> { ExternalCatalogImport.count }, 1 do
      result = ExternalCatalog::ImportCandidate.finalize_create!(
        lookup_result: @lookup_result,
        product: product,
        actor: @user
      )
      assert_equal :applied, result.status
    end
  end

  test "repeat finalize create does not duplicate import row" do
    product = Product.create!(
      title: "Edited Gatsby",
      catalog_item_type: "book",
      format: @paperback,
      publication_status: "active",
      active: true,
      product_type: "physical",
      variation_type: "conditional",
      sku: Phase65TestHelper::ISBNDB_SUCCESS_ISBN,
      name: "Edited Gatsby"
    )
    ExternalCatalog::ImportCandidate.finalize_create!(
      lookup_result: @lookup_result,
      product: product,
      actor: @user
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      ExternalCatalog::ImportCandidate.finalize_create!(
        lookup_result: @lookup_result,
        product: product,
        actor: @user
      )
    end
  end

  test "duplicate isbn routes to link and fill blank actions" do
    existing = Product.create!(
      title: "Existing",
      catalog_item_type: "book",
      format: @paperback,
      publication_status: "active",
      active: true,
      product_type: "physical",
      variation_type: "conditional",
      sku: Phase65TestHelper::ISBNDB_SUCCESS_ISBN,
      name: "Existing"
    )

    preview = ExternalCatalog::ImportPreview.call(lookup_result: @lookup_result)
    assert preview.duplicate.duplicate?
    assert_includes preview.allowed_actions, "fill_blank_existing_catalog_item"

    result = ExternalCatalog::ImportCandidate.call(
      lookup_result: @lookup_result,
      action_type: "fill_blank_existing_catalog_item",
      actor: @user,
      catalog_item_id: existing.id
    )

    assert_equal :applied, result.status
    existing.reload
    assert_equal "Existing", existing.title
    assert_equal "Scribner", existing.publisher
    assert_equal "Fitzgerald, F. Scott [author]", existing.creators
    assert_equal "Fiction; Classics", existing.themes
  end

  test "fill blank leaves populated creators and themes unchanged" do
    existing = Product.create!(
      title: "Existing",
      catalog_item_type: "book",
      format: @paperback,
      publication_status: "active",
      active: true,
      product_type: "physical",
      variation_type: "conditional",
      sku: Phase65TestHelper::ISBNDB_SUCCESS_ISBN,
      name: "Existing",
      creators: "Local Author [author]",
      themes: "Local Theme"
    )

    result = ExternalCatalog::ImportCandidate.call(
      lookup_result: @lookup_result,
      action_type: "fill_blank_existing_catalog_item",
      actor: @user,
      catalog_item_id: existing.id
    )

    assert_equal :applied, result.status
    existing.reload
    assert_equal "Local Author [author]", existing.creators
    assert_equal "Local Theme", existing.themes
    assert_equal "Scribner", existing.publisher
  end

  test "resolve_boundary_product_id resolves through catalog item when product id collides" do
    catalog_item = create_catalog_item!(title: "Linked Catalog Shell")
    linked_product = create_legacy_catalog_linked_product!(catalog_item: catalog_item, skip_product_identifier: true)
    stray_product = create_product!(skip_product_identifier: true, title: "Unrelated Product")

    Product.where(id: stray_product.id).update_all(id: catalog_item.id)
    stray_product = Product.find(catalog_item.id)
    refute_equal linked_product.id, stray_product.id

    resolved = ExternalCatalog::ImportCandidate.resolve_boundary_product_id(
      product_id: nil,
      catalog_item_id: catalog_item.id
    )

    assert_equal linked_product.id, resolved
  end

  test "resolve_boundary_product_id returns nil when catalog item id does not exist" do
    stray_product = create_product!(skip_product_identifier: true)

    resolved = ExternalCatalog::ImportCandidate.resolve_boundary_product_id(
      product_id: nil,
      catalog_item_id: stray_product.id
    )

    assert_nil resolved
  end

  private

  def persist_lookup_result_from_fixture!(name)
    payload = isbndb_fixture(name)
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
