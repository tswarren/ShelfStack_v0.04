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
      :root_available
    ) do
      def tokens
        [ canonical, *aliases, *legacy_aliases ].map { |token| CommandRegistry.normalize_token(token) }.uniq
      end

      def display_aliases
        (aliases + legacy_aliases).uniq
      end
    end

    Match = Data.define(:command, :args, :raw_input)

    Availability = Data.define(:available, :message)

    NOT_PROVIDED = Object.new

    ROOT_UNAVAILABLE_MESSAGE = "That command is not available from the idle workspace yet."
    NO_ACTIVE_TRANSACTION_MESSAGE = "No active transaction. Start a sale or scan an item first."
    NO_REGISTER_SESSION_MESSAGE = "Open the register before using this command."
    PERMISSION_DENIED_MESSAGE = "You are not authorized to use this command."

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

      def help_pattern
        ensure_loaded!
        tokens = help_tokens.flat_map do |token|
          normalized = token.sub(/\A\//, "")
          [ Regexp.escape("/#{normalized}"), Regexp.escape(normalized) ]
        end.uniq
        /\A(?:#{tokens.join("|")})\z/i
      end

      def normalize_token(token)
        token.to_s.strip.sub(/\A\//, "").downcase
      end

      def availability(command:, context:, user: nil, store: nil, register_session: NOT_PROVIDED, transaction: nil, check_permissions: false)
        return Availability.new(available: false, message: command.unavailable_message) if command.planned

        if command.register_session_required && register_session != NOT_PROVIDED && register_session.blank?
          return Availability.new(available: false, message: NO_REGISTER_SESSION_MESSAGE)
        end

        if command.transaction_required && transaction.blank?
          return Availability.new(available: false, message: NO_ACTIVE_TRANSACTION_MESSAGE)
        end

        if context == :root && !command.root_available
          return Availability.new(available: false, message: ROOT_UNAVAILABLE_MESSAGE)
        end

        if check_permissions && user.present? && store.present? && command.permission_keys.any?
          allowed = command.permission_keys.any? do |permission_key|
            Authorization.allowed?(user: user, permission_key: permission_key, store: store)
          end
          return Availability.new(available: false, message: PERMISSION_DENIED_MESSAGE) unless allowed
        end

        Availability.new(available: true, message: nil)
      end

      def help_message(user: nil, store: nil, register_session: nil, transaction: nil, context: :root)
        ensure_loaded!
        lines = [ "POS commands:" ]

        catalog.each do |command|
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

          suffix = if command.planned
            " (planned)"
          elsif !availability.available
            " (unavailable)"
          end

          alias_text = display_alias_text(command)
          lines << "  #{command.canonical}#{alias_text} — #{command.description}#{suffix}"
        end

        lines << "Use #{self[:help].canonical} for this list."
        lines.join("\n")
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
        aliases = command.display_aliases
        return "" if aliases.empty?

        " (#{aliases.map { |token| token.start_with?("/") ? token : "/#{token}" }.join(", ")})"
      end
    end
  end
end
