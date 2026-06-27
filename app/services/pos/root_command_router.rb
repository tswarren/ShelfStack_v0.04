# frozen_string_literal: true

module Pos
  class RootCommandRouter
    HELP_MESSAGE = "Commands: /help, /balance, /op, /gc. Full command list ships in a later update."
    DISABLED_COMMAND_MESSAGE = "That command is not available from the idle workspace yet."
    GC_STUB_MESSAGE = "Gift card sales from the command field ship in a later update. Start a new sale first."

    Route = LookupLaneRouter::Route

    OP_COMMAND_PATTERN = /\A\/(?:op|openring)(?:\s+\d+(?:\.\d{1,2})?)?\z/i
    GC_COMMAND_PATTERN = /\A\/(?:gc|giftcard)(?:\s+\d+(?:\.\d{1,2})?)?\z/i
    HELP_COMMAND_PATTERN = /\A\/help\z/i
    BALANCE_COMMAND_PATTERN = /\A\/balance\z/i

    def self.call(store:, input:)
      new(store: store, input: input).call
    end

    def initialize(store:, input:)
      @store = store
      @parsed = CommandParser.parse(input)
    end

    def call
      case parsed.lane
      when :empty
        Route.new(action: :empty, payload: {}, message: CommandParser::EMPTY_INPUT_MESSAGE)
      when :command
        slash_route
      when :lookup
        LookupLaneRouter.call(store: store, query: parsed.input, context: :root)
      else
        raise ArgumentError, "Unexpected parser lane: #{parsed.lane.inspect}"
      end
    end

    private

    attr_reader :store, :parsed

    def slash_route
      input = parsed.input

      return Route.new(action: :help, payload: {}, message: HELP_MESSAGE) if input.match?(HELP_COMMAND_PATTERN)
      return Route.new(action: :balance_redirect, payload: {}, message: nil) if input.match?(BALANCE_COMMAND_PATTERN)
      return Route.new(action: :disabled_command, payload: {}, message: GC_STUB_MESSAGE) if input.match?(GC_COMMAND_PATTERN)
      return Route.new(action: :disabled_command, payload: {}, message: DISABLED_COMMAND_MESSAGE) if input.match?(OP_COMMAND_PATTERN)

      Route.new(action: :message, payload: {}, message: CommandParser::UNKNOWN_COMMAND_MESSAGE)
    end
  end
end
