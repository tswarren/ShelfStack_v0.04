# frozen_string_literal: true

require "test_helper"

class Pos::CommandBarRouterTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @variant = create_product_variant!(selling_price_cents: 1000)
  end

  test "variant lookup wins over receipt-shaped input" do
    sku = @variant.sku
    route = Pos::CommandBarRouter.call(store: @store, input: sku)

    assert_equal :variant_lookup, route.action
    assert route.payload[:variants].any?
  end

  test "receipt lookup when no variant match and receipt format" do
    route = Pos::CommandBarRouter.call(store: @store, input: "001-001-000042")

    assert_equal :receipt_lookup, route.action
    assert_equal "001-001-000042", route.payload[:transaction_number]
  end

  test "open ring offer for unmatched non-receipt input" do
    route = Pos::CommandBarRouter.call(store: @store, input: "Custom gift wrap")

    assert_equal :open_ring_offer, route.action
  end

  test "isbn lookup routes to variant lookup with multiple matches" do
    seed_phase3_reference_data!
    catalog_item = create_catalog_item!(title: "Router Multi Book")
    CatalogIdentifierService.add_identifier!(
      catalog_item: catalog_item,
      identifier_type: "isbn13",
      value: "9780143127741",
      primary: true
    )
    product = create_product!(catalog_item: catalog_item, sku: "9780143127741")
    variant = create_product_variant!(product: product, sub_department: @variant.sub_department, sku: "9780143127741", selling_price_cents: 1200)
    create_product_variant!(
      product: product,
      sub_department: @variant.sub_department,
      condition: ProductCondition.find_by!(condition_key: "used_good"),
      sku: "9780143127741UG",
      selling_price_cents: 800
    )

    route = Pos::CommandBarRouter.call(store: @store, input: "9780143127741")

    assert_equal :variant_lookup, route.action
    assert_equal :ambiguous, route.payload[:status]
    assert_equal 2, route.payload[:variants].size
    assert_includes route.payload[:variants].map(&:id), variant.id
  end

  test "long numeric barcode input does not treat scan as dollar amount" do
    route = Pos::CommandBarRouter.call(store: @store, input: "9780143127741")

    assert_nil route.payload[:amount_cents]
  end

  test "gift card command with amount routes to gift card sale" do
    route = Pos::CommandBarRouter.call(store: @store, input: "/giftcard 25")

    assert_equal :gift_card_sale, route.action
    assert_equal 2500, route.payload[:amount_cents]
  end

  test "gift card command without amount opens drawer offer" do
    route = Pos::CommandBarRouter.call(store: @store, input: "/giftcard")

    assert_equal :gift_card_sale_offer, route.action
  end
end
