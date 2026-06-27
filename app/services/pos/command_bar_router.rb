# frozen_string_literal: true

module Pos
  class CommandBarRouter
    BALANCE_COMMAND_PATTERN = /\A\/balance\z/i
    GIFT_CARD_COMMAND_PATTERN = /\A\/(?:gc|giftcard)(?:\s+(\d+(?:\.\d{1,2})?))?\z/i
    LINE_DISCOUNT_COMMAND_PATTERN = /\A\/d\z/i
    TRANSACTION_DISCOUNT_COMMAND_PATTERN = /\A\/dt\z/i

    Route = LookupLaneRouter::Route

    def self.call(store:, input:, return_mode: false, transaction: nil)
      new(store:, input:, return_mode:, transaction:).call
    end

    def initialize(store:, input:, return_mode: false, transaction: nil)
      @store = store
      @parsed = CommandParser.parse(input)
      @return_mode = return_mode
      @transaction = transaction
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

    attr_reader :store, :parsed, :return_mode, :transaction

    def slash_route
      input = parsed.input

      return gift_card_route if input.match?(GIFT_CARD_COMMAND_PATTERN)
      return line_discount_route if input.match?(LINE_DISCOUNT_COMMAND_PATTERN)
      return Route.new(action: :transaction_discount_offer, payload: {}, message: nil) if input.match?(TRANSACTION_DISCOUNT_COMMAND_PATTERN)
      return Route.new(action: :balance_inquiry_offer, payload: {}, message: nil) if input.match?(BALANCE_COMMAND_PATTERN)

      Route.new(action: :message, payload: {}, message: CommandParser::UNKNOWN_COMMAND_MESSAGE)
    end

    def line_discount_route
      line = previous_discountable_line
      if line.blank?
        return Route.new(
          action: :line_discount_offer,
          payload: {},
          message: "No line available for discount."
        )
      end

      Route.new(action: :line_discount_offer, payload: { line_id: line.id }, message: nil)
    end

    def previous_discountable_line
      return if transaction.blank?

      transaction.pos_transaction_lines
               .where("quantity > 0")
               .where.not(line_type: "gift_card_sale")
               .reorder(line_number: :desc, id: :desc)
               .detect do |line|
        remaining = [
          line.unit_price_cents.to_i * line.quantity.abs -
            line.line_discount_cents.to_i -
            line.transaction_discount_cents.to_i,
          0
        ].max

        DiscountEligibilityResolver.call(line, remaining_discountable_cents: remaining).discountable
      end
    end

    def gift_card_route
      match = parsed.input.match(GIFT_CARD_COMMAND_PATTERN)
      amount = match[1]
      if amount.present?
        Route.new(
          action: :gift_card_sale,
          payload: { amount_cents: (BigDecimal(amount) * 100).round.to_i },
          message: nil
        )
      else
        Route.new(action: :gift_card_sale_offer, payload: {}, message: nil)
      end
    end
  end
end
