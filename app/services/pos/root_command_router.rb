# frozen_string_literal: true

module Pos
  class RootCommandRouter
    FAILED_LOOKUP_MESSAGE = "No matching item. Use /op for open ring, /return for receipt lookup, or /help."
    HELP_MESSAGE = "Commands: /help, /balance, /op, /gc. Full command list ships in a later update."
    DISABLED_COMMAND_MESSAGE = "That command is not available from the idle workspace yet."
    GC_STUB_MESSAGE = "Gift card sales from the command field ship in a later update. Start a new sale first."

    Route = Data.define(:action, :payload, :message)

    OP_COMMAND_PATTERN = /\A\/(?:op|openring)(?:\s+\d+(?:\.\d{1,2})?)?\z/i
    GC_COMMAND_PATTERN = /\A\/(?:gc|giftcard)(?:\s+\d+(?:\.\d{1,2})?)?\z/i
    HELP_COMMAND_PATTERN = /\A\/help\z/i
    BALANCE_COMMAND_PATTERN = /\A\/balance\z/i

    def self.call(store:, input:)
      new(store: store, input: input).call
    end

    def initialize(store:, input:)
      @store = store
      @input = input.to_s.strip
    end

    def call
      return Route.new(action: :empty, payload: {}, message: "Enter a SKU, ISBN, or command.") if input.blank?
      return slash_route if input.start_with?("/")

      lookup_route
    end

    private

    attr_reader :store, :input

    def slash_route
      return Route.new(action: :help, payload: {}, message: HELP_MESSAGE) if input.match?(HELP_COMMAND_PATTERN)
      return Route.new(action: :balance_redirect, payload: {}, message: nil) if input.match?(BALANCE_COMMAND_PATTERN)
      return Route.new(action: :disabled_command, payload: {}, message: GC_STUB_MESSAGE) if input.match?(GC_COMMAND_PATTERN)
      return Route.new(action: :disabled_command, payload: {}, message: DISABLED_COMMAND_MESSAGE) if input.match?(OP_COMMAND_PATTERN)

      Route.new(action: :message, payload: {}, message: FAILED_LOOKUP_MESSAGE)
    end

    def lookup_route
      lookup = LineLookup.call(store: store, query: input)

      if lookup.variants.one?
        return Route.new(
          action: :add_variant,
          payload: { variant_id: lookup.variants.first.id },
          message: nil
        )
      end

      if lookup.variants.many?
        return Route.new(
          action: :variant_lookup,
          payload: { status: lookup.status, variants: lookup.variants },
          message: lookup.message
        )
      end

      Route.new(action: :message, payload: {}, message: FAILED_LOOKUP_MESSAGE)
    end
  end
end
