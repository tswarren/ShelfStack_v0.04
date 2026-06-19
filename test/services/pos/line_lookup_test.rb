# frozen_string_literal: true

require "test_helper"

class Pos::LineLookupTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @variant = create_product_variant!(sku: "POS-VAR-001")
    @product = @variant.product
    @product.update!(sku: "POS-PROD-001")
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
end
