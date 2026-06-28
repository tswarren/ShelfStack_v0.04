# frozen_string_literal: true

module Pos
  class CommandRouteBuilder
    Route = LookupLaneRouter::Route

    NOT_YET_AVAILABLE_MESSAGE = "That command is not available yet."
    RETURN_BLOCKED_TENDERS_MESSAGE = "Complete, cancel, hold, or clear settlement before adding return lines."
    INVALID_AMOUNT_MESSAGE = "Amount must be a valid dollar amount."
    INVALID_DISCOUNT_MESSAGE = "Discount must be a whole-number percent or a dollar amount with cents."
    TENDER_AMOUNT_REJECTED_MESSAGE = "/tender does not accept an amount. Use /cash 20, /card 20, /check 20, /giftredeem 20, or /storecredit 20."
    CLOSE_BLOCKED_MESSAGE = "Cannot close register while a transaction is active. Complete, cancel, or hold the current transaction first."
    REPORTS_CONFIRM_MESSAGE = "Leave the current transaction and open Reports? The draft will remain on the server."

    TENDER_TYPE_BY_HANDLER = {
      tender_cash: "cash",
      tender_card: "card",
      tender_check: "check",
      tender_store_credit: "stored_value",
      gift_redeem: "stored_value"
    }.freeze

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
        check_permissions: true
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
          payload: {
            commands: CommandRegistry.help_entries(
              user: user,
              store: store,
              register_session: register_session,
              transaction: transaction,
              context: context
            ),
            category_labels: CommandRegistry::HELP_CATEGORIES
          },
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
      when :return_drawer
        return_drawer_route
      when :pickup_drawer
        pickup_drawer_route
      when :line_discount
        line_discount_route
      when :transaction_discount
        transaction_discount_route
      when :settlement_modal
        settlement_modal_route
      when :tender_cash, :tender_card, :tender_check, :tender_store_credit, :gift_redeem
        settlement_tender_route(TENDER_TYPE_BY_HANDLER.fetch(command.handler))
      when :session_drawer
        Route.new(action: :session_drawer_offer, payload: { focus: "session" }, message: nil)
      when :held_transactions_drawer
        Route.new(action: :session_drawer_offer, payload: { focus: "held" }, message: nil)
      when :reports
        reports_route
      when :close_register
        close_register_route
      when :cash_in, :cash_out
        cash_movement_route(command.handler)
      when :drawer_action
        drawer_action_route
      when :customer_lookup
        customer_lookup_route
      when :tax_exempt
        Route.new(action: :tax_exemption_offer, payload: {}, message: nil)
      else
        raise ArgumentError, "No route handler wired for #{command.key.inspect}"
      end
    end

    def balance_route
      Route.new(action: :balance_inquiry_offer, payload: {}, message: nil)
    end

    def customer_lookup_route
      payload = {}
      payload[:query] = match.args.strip if match.args.present?

      Route.new(action: :customer_lookup_offer, payload: payload, message: nil)
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

    def return_drawer_route
      if transaction.present? && transaction.pos_tenders.settlement_rows.exists?
        return Route.new(action: :message, payload: {}, message: RETURN_BLOCKED_TENDERS_MESSAGE)
      end

      payload = {}
      payload[:receipt_number] = match.args.strip if match.args.present?

      Route.new(action: :return_drawer_offer, payload: payload, message: nil)
    end

    def pickup_drawer_route
      Route.new(action: :pickup_drawer_offer, payload: {}, message: nil)
    end

    def settlement_modal_route
      if match.args.present?
        return Route.new(action: :message, payload: {}, message: TENDER_AMOUNT_REJECTED_MESSAGE)
      end

      Route.new(action: :settlement_offer, payload: {}, message: nil)
    end

    def settlement_tender_route(tender_type)
      return invalid_amount_route if invalid_amount_args?

      payload = { tender_type: tender_type }
      amount_cents = parse_amount_cents(match.args)
      if amount_cents.present?
        payload[:amount_cents] = amount_cents
      else
        payload[:prefill_remaining] = true
      end

      Route.new(action: :settlement_offer, payload: payload, message: nil)
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

    def transaction_discount_route
      return invalid_discount_route if invalid_discount_args?

      Route.new(action: :transaction_discount_offer, payload: discount_payload, message: nil)
    end

    def line_discount_route
      return invalid_discount_route if invalid_discount_args?

      line = previous_discountable_line
      if line.blank?
        return Route.new(
          action: :line_discount_offer,
          payload: {},
          message: "No line available for discount."
        )
      end

      Route.new(
        action: :line_discount_offer,
        payload: { line_id: line.id }.merge(discount_payload),
        message: nil
      )
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

    def discount_payload
      parsed = parse_discount_args(match.args)
      return {} if parsed.blank?

      payload = {
        discount_type: parsed[:discount_type],
        discount_value: parsed[:discount_value]
      }
      payload[:focus] = "amount"
      payload
    end

    def invalid_discount_args?
      match.args.present? && parse_discount_args(match.args) == :invalid
    end

    def invalid_discount_route
      Route.new(action: :message, payload: {}, message: INVALID_DISCOUNT_MESSAGE)
    end

    def parse_discount_args(args)
      return if args.blank?

      normalized = args.strip.delete_prefix("$").delete_suffix("%").strip
      return :invalid if normalized.blank?

      if normalized.include?(".")
        return :invalid unless normalized.match?(/\A\d+(?:\.\d{1,2})?\z/)

        amount = BigDecimal(normalized)
        return :invalid if amount <= 0

        { discount_type: "amount", discount_value: format("%.2f", amount) }
      else
        return :invalid unless normalized.match?(/\A\d+\z/)

        percent = normalized.to_i
        return :invalid if percent <= 0 || percent > 100

        { discount_type: "percent", discount_value: normalized }
      end
    end

    def reports_route
      if active_draft_present?
        Route.new(
          action: :reports_confirm_offer,
          payload: { url: reports_root_url },
          message: REPORTS_CONFIRM_MESSAGE
        )
      else
        Route.new(action: :redirect, payload: { url: reports_root_url }, message: nil)
      end
    end

    def close_register_route
      if active_draft_present?
        return Route.new(action: :message, payload: {}, message: CLOSE_BLOCKED_MESSAGE)
      end

      if register_session.blank?
        return Route.new(action: :message, payload: {}, message: CommandRegistry::NO_REGISTER_SESSION_MESSAGE)
      end

      Route.new(
        action: :redirect,
        payload: { url: close_register_url },
        message: nil
      )
    end

    def cash_movement_route(handler)
      return invalid_amount_route if invalid_amount_args?

      movement_type = handler == :cash_in ? "paid_in" : "paid_out"
      payload = { movement_type: movement_type }
      amount_cents = parse_amount_cents(match.args)
      payload[:amount_cents] = amount_cents if amount_cents.present?

      Route.new(action: :cash_movement_offer, payload: payload, message: nil)
    end

    def drawer_action_route
      Route.new(
        action: :drawer_action_offer,
        payload: { reason: match.args.strip.presence },
        message: nil
      )
    end

    def active_draft_present?
      return true if transaction.present? && transaction.status == "draft"

      return false unless context == :root && register_session.present?

      PosTransaction.drafts.where(
        store: store,
        workstation: register_session.workstation,
        pos_register_session: register_session
      ).exists?
    end

    def reports_root_url
      Rails.application.routes.url_helpers.reports_root_path
    end

    def close_register_url
      "#{Rails.application.routes.url_helpers.pos_register_session_path(register_session)}#close-register"
    end

    def unavailable_route(availability)
      Route.new(action: availability.action, payload: {}, message: availability.message)
    end
  end
end
