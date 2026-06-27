# frozen_string_literal: true

module Pos
  class CommandBarRouter
    BALANCE_COMMAND_PATTERN = /\A\/balance\z/i
    GIFT_CARD_COMMAND_PATTERN = /\A\/giftcard(?:\s+(\d+(?:\.\d{1,2})?))?\z/i
    LINE_DISCOUNT_COMMAND_PATTERN = /\A\/d\z/i
    TRANSACTION_DISCOUNT_COMMAND_PATTERN = /\A\/dt\z/i

    Route = Data.define(:action, :payload, :message)

    FAILED_LOOKUP_MESSAGE = RootCommandRouter::FAILED_LOOKUP_MESSAGE

    def self.call(store:, input:, return_mode: false, transaction: nil)
      new(store:, input:, return_mode:, transaction:).call
    end

    def initialize(store:, input:, return_mode: false, transaction: nil)
      @store = store
      @input = input.to_s.strip
      @return_mode = return_mode
      @transaction = transaction
    end

    def call
      return Route.new(action: :empty, payload: {}, message: "Enter a SKU, ISBN, receipt number, or command.") if input.blank?

      if gift_card_command?
        return gift_card_route
      end

      if line_discount_command?
        return line_discount_route
      end

      if transaction_discount_command?
        return Route.new(action: :transaction_discount_offer, payload: {}, message: nil)
      end

      if balance_command?
        return Route.new(action: :balance_inquiry_offer, payload: {}, message: nil)
      end

      if lookup.variants.any?
        return Route.new(
          action: :variant_lookup,
          payload: { status: lookup.status, variants: lookup.variants },
          message: lookup.message
        )
      end

      Route.new(action: :message, payload: {}, message: FAILED_LOOKUP_MESSAGE)
    end

    private

    attr_reader :store, :input, :return_mode, :transaction

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

    def gift_card_command?
      input.match?(GIFT_CARD_COMMAND_PATTERN)
    end

    def balance_command?
      input.match?(BALANCE_COMMAND_PATTERN)
    end

    def line_discount_command?
      input.match?(LINE_DISCOUNT_COMMAND_PATTERN)
    end

    def transaction_discount_command?
      input.match?(TRANSACTION_DISCOUNT_COMMAND_PATTERN)
    end

    def gift_card_route
      match = input.match(GIFT_CARD_COMMAND_PATTERN)
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

    def lookup
      @lookup ||= LineLookup.call(store: store, query: input)
    end

  end
end
