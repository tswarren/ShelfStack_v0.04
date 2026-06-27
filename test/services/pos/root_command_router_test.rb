# frozen_string_literal: true

require "test_helper"

class Pos::RootCommandRouterTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @variant = create_product_variant!(selling_price_cents: 1000)
    @user = create_user!
    @workstation = create_workstation!(store: @store)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    grant_all_phase6_permissions!(@user, store: @store)
    grant_pos_stored_value_tender_permissions!(@user, store: @store)
  end

  test "single variant match returns add_variant action" do
    route = Pos::RootCommandRouter.call(store: @store, input: @variant.sku)

    assert_equal :add_variant, route.action
    assert_equal @variant.id, route.payload[:variant_id]
  end

  test "failed lookup returns message action" do
    route = Pos::RootCommandRouter.call(store: @store, input: "not-a-real-item")

    assert_equal :message, route.action
    assert_equal Pos::CommandParser::FAILED_LOOKUP_MESSAGE, route.message
  end

  test "bare amount returns failed lookup message" do
    route = Pos::RootCommandRouter.call(store: @store, input: "20")

    assert_equal :message, route.action
  end

  test "/gc returns gift card sale offer with prefilled amount" do
    route = Pos::RootCommandRouter.call(
      store: @store,
      register_session: @register_session,
      user: @user,
      input: "/gc 50"
    )

    assert_equal :gift_card_sale_offer, route.action
    assert_equal 5000, route.payload[:amount_cents]
  end

  test "/gc abc returns invalid amount message" do
    route = Pos::RootCommandRouter.call(
      store: @store,
      register_session: @register_session,
      user: @user,
      input: "/gc abc"
    )

    assert_equal :message, route.action
    assert_equal Pos::CommandRouteBuilder::INVALID_AMOUNT_MESSAGE, route.message
  end

  test "/op returns open ring offer with prefilled amount" do
    route = Pos::RootCommandRouter.call(
      store: @store,
      register_session: @register_session,
      user: @user,
      input: "/op 10"
    )

    assert_equal :open_ring_offer, route.action
    assert_equal 1000, route.payload[:amount_cents]
  end

  test "/op abc returns invalid amount message" do
    route = Pos::RootCommandRouter.call(
      store: @store,
      register_session: @register_session,
      user: @user,
      input: "/op abc"
    )

    assert_equal :message, route.action
    assert_equal Pos::CommandRouteBuilder::INVALID_AMOUNT_MESSAGE, route.message
  end

  test "/? returns help action" do
    route = Pos::RootCommandRouter.call(store: @store, input: "/?")

    assert_equal :help, route.action
  end

  test "bare ? returns help action" do
    route = Pos::RootCommandRouter.call(store: @store, input: "?")

    assert_equal :help, route.action
  end

  test "/help returns help action" do
    route = Pos::RootCommandRouter.call(store: @store, input: "/help")

    assert_equal :help, route.action
  end

  test "unknown slash command returns unknown command message" do
    route = Pos::RootCommandRouter.call(store: @store, input: "/foo")

    assert_equal :message, route.action
    assert_equal Pos::CommandParser::UNKNOWN_COMMAND_MESSAGE, route.message
  end

  test "/balance returns balance redirect action" do
    route = Pos::RootCommandRouter.call(
      store: @store,
      register_session: @register_session,
      input: "/balance"
    )

    assert_equal :balance_redirect, route.action
  end

  test "/cashdrop returns planned disabled message" do
    route = Pos::RootCommandRouter.call(
      store: @store,
      register_session: @register_session,
      input: "/drop"
    )

    assert_equal :message, route.action
    assert_equal Pos::CommandRegistry::Catalog::CASH_DROP_UNAVAILABLE_MESSAGE, route.message
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
