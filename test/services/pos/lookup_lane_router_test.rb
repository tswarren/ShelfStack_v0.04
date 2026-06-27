# frozen_string_literal: true

require "test_helper"

class Pos::LookupLaneRouterTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @variant = create_product_variant!(selling_price_cents: 1000)
  end

  test "root context returns add_variant for single match" do
    route = Pos::LookupLaneRouter.call(store: @store, query: @variant.sku, context: :root)

    assert_equal :add_variant, route.action
    assert_equal @variant.id, route.payload[:variant_id]
  end

  test "transaction context returns variant_lookup for single match" do
    route = Pos::LookupLaneRouter.call(store: @store, query: @variant.sku, context: :transaction)

    assert_equal :variant_lookup, route.action
    assert_equal 1, route.payload[:variants].size
  end

  test "receipt-shaped input returns failed lookup message" do
    route = Pos::LookupLaneRouter.call(store: @store, query: "001-001-000042", context: :root)

    assert_equal :message, route.action
    assert_equal Pos::CommandParser::FAILED_LOOKUP_MESSAGE, route.message
  end

  test "bare amount returns failed lookup message" do
    route = Pos::LookupLaneRouter.call(store: @store, query: "20", context: :transaction)

    assert_equal :message, route.action
  end

  test "raises for invalid context" do
    assert_raises(ArgumentError) do
      Pos::LookupLaneRouter.call(store: @store, query: @variant.sku, context: :invalid)
    end
  end
end
