# frozen_string_literal: true

module Pos
  class CommandBarRouter
    Route = LookupLaneRouter::Route

    def self.call(store:, input:, return_mode: false, transaction: nil, user: nil, register_session: nil)
      new(store:, input:, return_mode:, transaction:, user:, register_session:).call
    end

    def initialize(store:, input:, return_mode: false, transaction: nil, user: nil, register_session: nil)
      @store = store
      @parsed = CommandParser.parse(input)
      @return_mode = return_mode
      @transaction = transaction
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
        LookupLaneRouter.call(store: store, query: parsed.input, context: :transaction)
      else
        raise ArgumentError, "Unexpected parser lane: #{parsed.lane.inspect}"
      end
    end

    private

    attr_reader :store, :parsed, :return_mode, :transaction, :user, :register_session

    def slash_route
      match = CommandRegistry.resolve(parsed.input)
      return unknown_command_route unless match

      CommandRouteBuilder.call(
        match: match,
        context: :transaction,
        store: store,
        transaction: transaction,
        user: user,
        register_session: register_session
      )
    end

    def unknown_command_route
      Route.new(action: :message, payload: {}, message: CommandParser::UNKNOWN_COMMAND_MESSAGE)
    end
  end
end
