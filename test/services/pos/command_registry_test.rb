# frozen_string_literal: true

require "test_helper"

class Pos::CommandRegistryTest < ActiveSupport::TestCase
  test "resolve normalizes aliases to canonical commands" do
    assert_equal :linediscount, Pos::CommandRegistry.resolve("/d").command.key
    assert_equal :linediscount, Pos::CommandRegistry.resolve("/ld").command.key
    assert_equal :discount, Pos::CommandRegistry.resolve("/dt").command.key
    assert_equal :discount, Pos::CommandRegistry.resolve("/di").command.key
    assert_equal :giftcard, Pos::CommandRegistry.resolve("/gc 50").command.key
    assert_equal "50", Pos::CommandRegistry.resolve("/gc 50").args
    assert_equal :help, Pos::CommandRegistry.resolve("?").command.key
  end

  test "resolve returns nil for unknown commands" do
    assert_nil Pos::CommandRegistry.resolve("/foo")
  end

  test "aliases are unique across the registry" do
    assert Pos::CommandRegistry.commands.any?
    assert Pos::CommandRegistry.commands.map(&:key).uniq.size == Pos::CommandRegistry.commands.size
  end

  test "help message lists canonical commands and aliases" do
    message = Pos::CommandRegistry.help_message(context: :root)

    assert_includes message, "POS commands:"
    assert_includes message, "/linediscount (/ld, /d)"
    assert_includes message, "/cashdrop (/dp, /drop)"
    assert_includes message, "(planned)"
    assert_includes message, "/giftcard (/gc) — Gift card issue or reload"
    assert_not_includes message, "/giftcard (/gc) — Gift card issue or reload (unavailable)"
  end

  test "cashdrop is planned and unavailable" do
    command = Pos::CommandRegistry[:cashdrop]
    store = create_store!
    workstation = create_workstation!(store: store)
    user = create_user!
    register_session = open_register_session!(store: store, workstation: workstation, user: user)

    assert command.planned
    availability = Pos::CommandRegistry.availability(
      command: command,
      context: :root,
      user: nil,
      store: store,
      register_session: register_session
    )

    assert_not availability.available
    assert_equal Pos::CommandRegistry::Catalog::CASH_DROP_UNAVAILABLE_MESSAGE, availability.message
  end

  test "transaction-required commands are unavailable without a transaction" do
    command = Pos::CommandRegistry[:linediscount]
    availability = Pos::CommandRegistry.availability(
      command: command,
      context: :transaction,
      user: nil,
      store: create_store!,
      register_session: Pos::CommandRegistry::NOT_PROVIDED,
      transaction: nil
    )

    assert_not availability.available
    assert_equal Pos::CommandRegistry::NO_ACTIVE_TRANSACTION_MESSAGE, availability.message
  end

  test "unimplemented commands are unavailable for routing" do
    command = Pos::CommandRegistry[:customer]
    availability = Pos::CommandRegistry.availability(
      command: command,
      context: :root,
      user: nil,
      store: create_store!,
      register_session: Pos::CommandRegistry::NOT_PROVIDED
    )

    assert_not availability.available
    assert_equal Pos::CommandRouteBuilder::NOT_YET_AVAILABLE_MESSAGE, availability.message
  end

  test "help pattern matches parser command-lane help tokens" do
    assert_match Pos::CommandParser::HELP_COMMAND_PATTERN, "/help"
    assert_match Pos::CommandParser::HELP_COMMAND_PATTERN, "/?"
    assert_match Pos::CommandParser::HELP_COMMAND_PATTERN, "?"
    assert_no_match Pos::CommandParser::HELP_COMMAND_PATTERN, "help"
  end
end
