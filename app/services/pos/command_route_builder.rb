# frozen_string_literal: true

module Pos
  class CommandRouteBuilder
    Route = LookupLaneRouter::Route

    NOT_YET_AVAILABLE_MESSAGE = "That command is not available yet."
    INVALID_AMOUNT_MESSAGE = "Amount must be a valid dollar amount."

    def self.call(match:, context:, store:, transaction: nil, user: nil, register_session: nil)
      new(
        match: match,
        context: context,
        store: store,
        transaction: transaction,
        user: user,
        register_session: register_session
      ).call
    end

    def initialize(match:, context:, store:, transaction: nil, user: nil, register_session: nil)
      @match = match
      @context = context
      @store = store
      @transaction = transaction
      @user = user
      @register_session = register_session
    end

    def call
      availability = CommandRegistry.availability(
        command: command,
        context: context,
        user: user,
        store: store,
        register_session: register_session,
        transaction: transaction,
        check_permissions: user.present? && store.present?
      )
      return unavailable_route(availability) unless availability.available

      handler_route
    end

    private

    attr_reader :match, :context, :store, :transaction, :user, :register_session

    def command
      match.command
    end

    def handler_route
      case command.handler
      when :help
        Route.new(
          action: :help,
          payload: {},
          message: CommandRegistry.help_message(
            user: user,
            store: store,
            register_session: register_session,
            transaction: transaction,
            context: context
          )
        )
      when :balance_inquiry
        balance_route
      when :open_ring
        open_ring_route
      when :gift_card_modal
        gift_card_route
      when :line_discount
        line_discount_route
      when :transaction_discount
        Route.new(action: :transaction_discount_offer, payload: {}, message: nil)
      else
        raise ArgumentError, "No route handler wired for #{command.key.inspect}"
      end
    end

    def balance_route
      if context == :root
        Route.new(action: :balance_redirect, payload: {}, message: nil)
      else
        Route.new(action: :balance_inquiry_offer, payload: {}, message: nil)
      end
    end

    def open_ring_route
      return invalid_amount_route if invalid_amount_args?

      Route.new(
        action: :open_ring_offer,
        payload: amount_payload,
        message: nil
      )
    end

    def gift_card_route
      return invalid_amount_route if invalid_amount_args?

      Route.new(
        action: :gift_card_sale_offer,
        payload: amount_payload,
        message: nil
      )
    end

    def amount_payload
      payload = {}
      amount_cents = parse_amount_cents(match.args)
      payload[:amount_cents] = amount_cents if amount_cents.present?
      payload
    end

    def invalid_amount_args?
      match.args.present? && parse_amount_cents(match.args).nil?
    end

    def invalid_amount_route
      Route.new(action: :message, payload: {}, message: INVALID_AMOUNT_MESSAGE)
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

    def parse_amount_cents(args)
      return if args.blank?

      normalized = args.delete_prefix("$")
      return unless normalized.match?(/\A\d+(?:\.\d{1,2})?\z/)

      (BigDecimal(normalized) * 100).round.to_i
    end

    def unavailable_route(availability)
      Route.new(action: availability.action, payload: {}, message: availability.message)
    end
  end
end
