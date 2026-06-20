# frozen_string_literal: true

require "test_helper"

class Pos::LineLookupTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @variant = create_product_variant!(sku: "POS-VAR-001")
    @product = @variant.product
    @product.update!(sku: "POS-PROD-001")

    seed_phase3_reference_data!
    @catalog_item = create_catalog_item!(title: "Multi Condition Book")
    CatalogIdentifierService.add_identifier!(
      catalog_item: @catalog_item,
      identifier_type: "isbn13",
      value: "9780306406157",
      primary: true
    )
    @isbn_product = create_product!(catalog_item: @catalog_item, sku: "9780306406157")
    @new_variant = create_product_variant!(
      product: @isbn_product,
      sub_department: @variant.sub_department,
      sku: "9780306406157",
      selling_price_cents: 1500
    )
    @used_variant = create_product_variant!(
      product: @isbn_product,
      sub_department: @variant.sub_department,
      condition: ProductCondition.find_by!(condition_key: "used_good"),
      sku: "9780306406157UG",
      selling_price_cents: 900
    )
  end

  test "variant sku ranks first" do
    result = Pos::LineLookup.call(store: @store, query: "POS-VAR-001")
    assert_equal :found, result.status
    assert_equal @variant.id, result.variants.first.id
  end

  test "product sku ranks before catalog identifier" do
    result = Pos::LineLookup.call(store: @store, query: "POS-PROD-001")
    assert_equal :found, result.status
    assert_equal @variant.id, result.variants.first.id
  end

  test "exact lookup finds inactive variant sku" do
    @variant.update!(active: false)

    result = Pos::LineLookup.call(store: @store, query: "POS-VAR-001")

    assert_equal :found, result.status
    assert_equal @variant.id, result.variants.first.id
    refute @variant.reload.active?
  end

  test "search does not return inactive variants" do
    @variant.update!(active: false)

    result = Pos::LineLookup.call(store: @store, query: "POS-VAR", mode: :search)

    assert_equal :not_found, result.status
  end

  test "inactive product sku resolves through inactive fallback" do
    variant = create_product_variant!(
      sub_department: @variant.sub_department,
      sku: "INACTIVE-VAR-PROD",
      active: true
    )
    product_sku = variant.product.sku
    variant.update!(active: false)

    result = Pos::LineLookup.call(store: @store, query: product_sku)

    assert_equal :found, result.status
    assert_equal variant.id, result.variants.first.id
  end

  test "isbn exact lookup returns ambiguous for multiple conditions" do
    result = Pos::LineLookup.call(store: @store, query: "9780306406157")

    assert_equal :ambiguous, result.status
    assert_equal [@new_variant.id, @used_variant.id].sort, result.variants.map(&:id).sort
  end

  test "formatted isbn search keeps multiple variants visible" do
    result = Pos::LineLookup.call(store: @store, query: "978-0-306-40615-7", mode: :search)

    assert_equal :search, result.status
    assert_equal 2, result.variants.size
  end

  test "isbn10 exact lookup resolves through isbn13 conversion" do
    result = Pos::LineLookup.call(store: @store, query: "0-306-40615-7")

    assert_equal :ambiguous, result.status
    assert_equal 2, result.variants.size
  end
end
