# frozen_string_literal: true

module Pos
  class CommandRegistry
    Command = Data.define(
      :key,
      :canonical,
      :aliases,
      :legacy_aliases,
      :description,
      :permission_keys,
      :transaction_required,
      :register_session_required,
      :handler,
      :planned,
      :unavailable_message,
      :unavailable_action,
      :root_implemented,
      :transaction_implemented,
      :root_available,
      :root_unavailable_message,
      :transaction_unavailable_message
    ) do
      def tokens
        [ canonical, *aliases, *legacy_aliases ].map { |token| CommandRegistry.normalize_token(token) }.uniq
      end

      def display_aliases
        (aliases + legacy_aliases).uniq
      end

      def implemented_for?(context)
        context == :root ? root_implemented : transaction_implemented
      end

      def routing_unavailable_message(context)
        case context
        when :root
          root_unavailable_message || unavailable_message
        when :transaction
          transaction_unavailable_message || unavailable_message
        else
          unavailable_message
        end
      end
    end

    Match = Data.define(:command, :args, :raw_input)

    Availability = Data.define(:available, :message, :action)

    NOT_PROVIDED = Object.new

    ROOT_UNAVAILABLE_MESSAGE = "That command is not available from the idle workspace yet."
    NO_ACTIVE_TRANSACTION_MESSAGE = "No active transaction. Start a sale or scan an item first."
    NO_REGISTER_SESSION_MESSAGE = "Open the register before using this command."
    PERMISSION_DENIED_MESSAGE = "You are not authorized to use this command."

    HELP_CATEGORIES = {
      "sale" => "Sale & items",
      "adjustments" => "Discounts & tax",
      "payment" => "Payment",
      "register" => "Register & cash"
    }.freeze

    HELP_CATEGORY_KEYS = {
      openring: "sale",
      giftcard: "sale",
      return: "sale",
      pickup: "sale",
      customer: "sale",
      linediscount: "adjustments",
      discount: "adjustments",
      taxexempt: "adjustments",
      tender: "payment",
      cash: "payment",
      card: "payment",
      check: "payment",
      storecredit: "payment",
      giftredeem: "payment",
      balance: "payment",
      hold: "register",
      session: "register",
      cashdrop: "register",
      cashin: "register",
      cashout: "register",
      close: "register",
      drawer: "register",
      reports: "register"
    }.freeze

    class << self
      def resolve(input)
        stripped = input.to_s.strip
        return nil if stripped.blank?

        ensure_loaded!
        parts = stripped.split(/\s+/, 2)
        token = normalize_token(parts.first)
        command = index[token]
        return nil unless command

        Match.new(command: command, args: parts[1].to_s.strip, raw_input: stripped)
      end

      def [](key)
        ensure_loaded!
        by_key[key.to_sym]
      end

      def commands
        ensure_loaded!
        catalog
      end

      def help_tokens
        ensure_loaded!
        self[:help].tokens
      end

      # Matches parser command-lane help tokens only (/help, /?, ?) — not bare "help".
      def help_pattern
        /\A(?:\/help|\/\?|\?)\z/i
      end

      def normalize_token(token)
        token.to_s.strip.sub(/\A\//, "").downcase
      end

      def availability(command:, context:, user: nil, store: nil, register_session: NOT_PROVIDED, transaction: nil, check_permissions: false)
        if command.planned
          return Availability.new(
            available: false,
            message: command.unavailable_message,
            action: command.unavailable_action
          )
        end

        if command.register_session_required && register_session != NOT_PROVIDED && register_session.blank?
          return Availability.new(
            available: false,
            message: NO_REGISTER_SESSION_MESSAGE,
            action: :message
          )
        end

        if command.transaction_required && transaction.blank?
          return Availability.new(
            available: false,
            message: NO_ACTIVE_TRANSACTION_MESSAGE,
            action: :message
          )
        end

        if context == :root && !command.root_available
          return Availability.new(
            available: false,
            message: ROOT_UNAVAILABLE_MESSAGE,
            action: :message
          )
        end

        unless command.implemented_for?(context)
          return Availability.new(
            available: false,
            message: command.routing_unavailable_message(context),
            action: command.unavailable_action
          )
        end

        if check_permissions && user.present? && store.present? && command.permission_keys.any?
          allowed = command.permission_keys.any? do |permission_key|
            Authorization.allowed?(user: user, permission_key: permission_key, store: store)
          end
          unless allowed
            return Availability.new(
              available: false,
              message: PERMISSION_DENIED_MESSAGE,
              action: :message
            )
          end
        end

        Availability.new(available: true, message: nil, action: nil)
      end

      def help_message(user: nil, store: nil, register_session: NOT_PROVIDED, transaction: nil, context: :root)
        lines = [ "POS commands:" ]

        help_entries(
          user: user,
          store: store,
          register_session: register_session,
          transaction: transaction,
          context: context
        ).each do |entry|
          suffix = help_status_suffix(entry[:status])
          alias_text = help_alias_text(entry[:aliases])
          lines << "  #{entry[:canonical]}#{alias_text} — #{entry[:description]}#{suffix}"
        end

        lines << "Use #{self[:help].canonical} for this list."
        lines.join("\n")
      end

      def help_entries(user: nil, store: nil, register_session: NOT_PROVIDED, transaction: nil, context: :root)
        ensure_loaded!

        catalog.filter_map do |command|
          next if command.key == :help

          availability = availability(
            command: command,
            context: context,
            user: user,
            store: store,
            register_session: register_session,
            transaction: transaction,
            check_permissions: user.present? && store.present?
          )

          {
            key: command.key.to_s,
            canonical: command.canonical,
            aliases: command.display_aliases,
            description: command.description,
            status: help_status_for(command, availability, context),
            category: help_category_for(command.key)
          }
        end
      end

      def register!(command)
        raise "CommandRegistry is frozen" if @frozen

        catalog << command
      end

      def freeze!
        build_indexes!
        @frozen = true
      end

      private

      def ensure_loaded!
        return if @frozen

        load_catalog!
        freeze!
      end

      def load_catalog!
        catalog.clear
        Catalog.load!(self)
      end

      def catalog
        @catalog ||= []
      end

      def index
        @index ||= {}
      end

      def by_key
        @by_key ||= {}
      end

      def build_indexes!
        index.clear
        by_key.clear
        seen = {}

        catalog.each do |command|
          by_key[command.key] = command
          command.tokens.each do |token|
            if seen.key?(token)
              raise ArgumentError, "Duplicate command token #{token.inspect} for #{command.key} and #{seen[token]}"
            end

            seen[token] = command.key
            index[token] = command
          end
        end
      end

      def display_alias_text(command)
        help_alias_text(command.display_aliases)
      end

      def help_alias_text(aliases)
        return "" if aliases.empty?

        " (#{aliases.map { |token| token.start_with?("/") ? token : "/#{token}" }.join(", ")})"
      end

      def help_status_for(command, availability, context)
        return "planned" if command.planned
        return "unavailable" if !command.implemented_for?(context) || !availability.available

        "available"
      end

      def help_status_suffix(status)
        case status
        when "planned" then " (planned)"
        when "unavailable" then " (unavailable)"
        else ""
        end
      end

      def help_category_for(key)
        HELP_CATEGORY_KEYS.fetch(key.to_sym, "register")
      end
    end
  end
end
