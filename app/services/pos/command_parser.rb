# frozen_string_literal: true

module Pos
  class CommandParser
    Result = Data.define(:lane, :input)

    HELP_ALIASES = %w[/help /? ?].freeze
    HELP_COMMAND_PATTERN = /\A(?:\/help|\/\?|\?)\z/i

    FAILED_LOOKUP_MESSAGE = "No matching item. Use /op for open ring, /return for receipt lookup, or /help."
    UNKNOWN_COMMAND_MESSAGE = "Unknown command. Use /help to see available commands."
    EMPTY_INPUT_MESSAGE = "Enter a SKU, ISBN, or command."

    def self.parse(input)
      stripped = input.to_s.strip
      return Result.new(lane: :empty, input: stripped) if stripped.blank?
      return Result.new(lane: :command, input: stripped) if stripped.start_with?("/") || stripped == "?"

      Result.new(lane: :lookup, input: stripped)
    end
  end
end
