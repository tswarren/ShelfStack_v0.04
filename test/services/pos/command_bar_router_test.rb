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
end
