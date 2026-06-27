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

  test "unknown slash command returns unknown command message" do
    route = Pos::RootCommandRouter.call(store: @store, input: "/foo")

    assert_equal :message, route.action
    assert_equal Pos::RootCommandRouter::UNKNOWN_COMMAND_MESSAGE, route.message
  end

  test "/balance returns balance redirect action" do
    route = Pos::RootCommandRouter.call(store: @store, input: "/balance")

    assert_equal :balance_redirect, route.action
  end
end

class Pos::RootCommandHandlerTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @cashier = create_user!(username: "root_handler_cashier")
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @cashier)
  end

  test "returns message when variant id does not exist" do
    result = Pos::RootCommandHandler.call(
      store: @store,
      workstation: @workstation,
      cashier_user: @cashier,
      register_session: @register_session,
      user_session: nil,
      input: nil,
      product_variant_id: 9_999_999
    )

    assert_equal :json, result.status
    assert_equal "message", result.json[:action]
    assert_equal "Item could not be found.", result.json[:message]
  end
end
