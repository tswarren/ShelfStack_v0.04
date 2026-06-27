# frozen_string_literal: true

require "test_helper"

class Pos::RootCommandRouterTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @variant = create_product_variant!(selling_price_cents: 1000)
  end

  test "single variant match returns add_variant action" do
    route = Pos::RootCommandRouter.call(store: @store, input: @variant.sku)

    assert_equal :add_variant, route.action
    assert_equal @variant.id, route.payload[:variant_id]
  end

  test "failed lookup returns message action" do
    route = Pos::RootCommandRouter.call(store: @store, input: "not-a-real-item")

    assert_equal :message, route.action
    assert_equal Pos::RootCommandRouter::FAILED_LOOKUP_MESSAGE, route.message
  end

  test "bare amount returns failed lookup message" do
    route = Pos::RootCommandRouter.call(store: @store, input: "20")

    assert_equal :message, route.action
  end

  test "/gc returns disabled command stub" do
    route = Pos::RootCommandRouter.call(store: @store, input: "/gc 50")

    assert_equal :disabled_command, route.action
    assert_match(/later update/i, route.message)
  end

  test "/help returns help action" do
    route = Pos::RootCommandRouter.call(store: @store, input: "/help")

    assert_equal :help, route.action
  end

  test "/balance returns balance redirect action" do
    route = Pos::RootCommandRouter.call(store: @store, input: "/balance")

    assert_equal :balance_redirect, route.action
  end
end
