# frozen_string_literal: true

require "test_helper"

class Inventory::VariantLookupTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @variant.update!(sku: "9780123456789")
  end

  test "exact sku match returns found" do
    result = Inventory::VariantLookup.call(query: "9780123456789")
    assert_equal :found, result.status
    assert_equal @variant.id, result.variants.first.id
  end

  test "catalog identifier match returns found" do
    catalog_item = @variant.product.catalog_item
    skip "variant not catalog-linked" unless catalog_item

    result = Inventory::VariantLookup.call(query: catalog_item.primary_identifier.normalized_identifier)
    assert_includes %i[found ambiguous], result.status
    assert_includes result.variants.map(&:id), @variant.id
  end

  test "ineligible variant returns ineligible status" do
    @variant.update!(inventory_behavior: "non_inventory")
    result = Inventory::VariantLookup.call(query: @variant.sku)
    assert_equal :ineligible, result.status
  end

  test "search mode returns prefix matches" do
    result = Inventory::VariantLookup.call(query: "9780123", mode: :search)
    assert_equal :search, result.status
    assert_includes result.variants.map(&:id), @variant.id
  end

  test "not found for unknown sku" do
    result = Inventory::VariantLookup.call(query: "does-not-exist")
    assert_equal :not_found, result.status
  end
end
