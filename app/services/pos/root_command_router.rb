# frozen_string_literal: true

module Pos
  class RootCommandRouter
    Route = LookupLaneRouter::Route

    def self.call(store:, input:, user: nil, register_session: nil)
      new(store: store, input: input, user: user, register_session: register_session).call
    end

    def initialize(store:, input:, user: nil, register_session: nil)
      @store = store
      @parsed = CommandParser.parse(input)
      @user = user
      @register_session = register_session
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

    attr_reader :store, :parsed, :user, :register_session

    def slash_route
      match = CommandRegistry.resolve(parsed.input)
      return unknown_command_route unless match

      CommandRouteBuilder.call(
        match: match,
        context: :root,
        store: store,
        user: user,
        register_session: register_session
      )
    end

    def unknown_command_route
      Route.new(action: :message, payload: {}, message: CommandParser::UNKNOWN_COMMAND_MESSAGE)
    end
  end
end
