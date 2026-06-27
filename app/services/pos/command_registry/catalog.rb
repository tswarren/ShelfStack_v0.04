# frozen_string_literal: true

module Pos
  class CommandRegistry
    module Catalog
      CASH_DROP_UNAVAILABLE_MESSAGE = "Cash drop is not available yet."

      module_function

      def load!(registry)
        [
          help_command,
          customer_command,
          openring_command,
          linediscount_command,
          discount_command,
          taxexempt_command,
          giftcard_command,
          giftredeem_command,
          balance_command,
          return_command,
          pickup_command,
          tender_command,
          cash_command,
          card_command,
          check_command,
          storecredit_command,
          hold_command,
          session_command,
          cashdrop_command,
          cashin_command,
          cashout_command,
          close_command,
          reports_command,
          drawer_command
        ].each { |command| registry.register!(command) }
      end

      def help_command
        Command.new(
          key: :help,
          canonical: "/help",
          aliases: %w[/? ?],
          legacy_aliases: [],
          description: "Show command help",
          permission_keys: [],
          transaction_required: false,
          register_session_required: false,
          handler: :help,
          planned: false,
          unavailable_message: nil,
          root_available: true
        )
      end

      def customer_command
        Command.new(
          key: :customer,
          canonical: "/customer",
          aliases: %w[cu],
          legacy_aliases: [],
          description: "Customer lookup",
          permission_keys: [ "pos.access" ],
          transaction_required: false,
          register_session_required: true,
          handler: :customer_lookup,
          planned: false,
          unavailable_message: nil,
          root_available: true
        )
      end

      def openring_command
        Command.new(
          key: :openring,
          canonical: "/openring",
          aliases: %w[op],
          legacy_aliases: %w[open],
          description: "Open-ring sale",
          permission_keys: [ "pos.lines.add.open_ring" ],
          transaction_required: false,
          register_session_required: true,
          handler: :open_ring,
          planned: false,
          unavailable_message: nil,
          root_available: true
        )
      end

      def linediscount_command
        Command.new(
          key: :linediscount,
          canonical: "/linediscount",
          aliases: %w[ld],
          legacy_aliases: %w[d],
          description: "Line discount",
          permission_keys: [ "pos.discounts.line.apply" ],
          transaction_required: true,
          register_session_required: true,
          handler: :line_discount,
          planned: false,
          unavailable_message: nil,
          root_available: false
        )
      end

      def discount_command
        Command.new(
          key: :discount,
          canonical: "/discount",
          aliases: %w[di],
          legacy_aliases: %w[dt],
          description: "Transaction discount",
          permission_keys: [ "pos.discounts.transaction.apply" ],
          transaction_required: true,
          register_session_required: true,
          handler: :transaction_discount,
          planned: false,
          unavailable_message: nil,
          root_available: false
        )
      end

      def taxexempt_command
        Command.new(
          key: :taxexempt,
          canonical: "/taxexempt",
          aliases: %w[tx],
          legacy_aliases: [],
          description: "Tax exemption",
          permission_keys: [ "pos.tax_exemptions.apply" ],
          transaction_required: true,
          register_session_required: true,
          handler: :tax_exempt,
          planned: false,
          unavailable_message: nil,
          root_available: false
        )
      end

      def giftcard_command
        Command.new(
          key: :giftcard,
          canonical: "/giftcard",
          aliases: %w[gc],
          legacy_aliases: [],
          description: "Gift card issue or reload",
          permission_keys: [ "pos.gift_cards.issue" ],
          transaction_required: false,
          register_session_required: true,
          handler: :gift_card_modal,
          planned: false,
          unavailable_message: nil,
          root_available: true
        )
      end

      def giftredeem_command
        Command.new(
          key: :giftredeem,
          canonical: "/giftredeem",
          aliases: %w[gr],
          legacy_aliases: [],
          description: "Gift card redemption tender",
          permission_keys: [ "pos.tenders.gift_card" ],
          transaction_required: true,
          register_session_required: true,
          handler: :gift_redeem,
          planned: false,
          unavailable_message: nil,
          root_available: false
        )
      end

      def balance_command
        Command.new(
          key: :balance,
          canonical: "/balance",
          aliases: %w[bl],
          legacy_aliases: [],
          description: "Stored value balance inquiry",
          permission_keys: [ "pos.tenders.gift_card", "pos.tenders.store_credit" ],
          transaction_required: false,
          register_session_required: true,
          handler: :balance_inquiry,
          planned: false,
          unavailable_message: nil,
          root_available: true
        )
      end

      def return_command
        Command.new(
          key: :return,
          canonical: "/return",
          aliases: %w[rt],
          legacy_aliases: [],
          description: "Return workflow",
          permission_keys: [ "pos.returns.receipted" ],
          transaction_required: false,
          register_session_required: true,
          handler: :return_drawer,
          planned: false,
          unavailable_message: nil,
          root_available: true
        )
      end

      def pickup_command
        Command.new(
          key: :pickup,
          canonical: "/pickup",
          aliases: %w[pu],
          legacy_aliases: [],
          description: "Customer pickup workflow",
          permission_keys: [ "pos.access" ],
          transaction_required: false,
          register_session_required: true,
          handler: :pickup_drawer,
          planned: false,
          unavailable_message: nil,
          root_available: true
        )
      end

      def tender_command
        Command.new(
          key: :tender,
          canonical: "/tender",
          aliases: %w[tn],
          legacy_aliases: [],
          description: "Settlement modal",
          permission_keys: [ "pos.tenders.cash", "pos.tenders.card", "pos.tenders.check", "pos.tenders.gift_card", "pos.tenders.store_credit" ],
          transaction_required: true,
          register_session_required: true,
          handler: :settlement_modal,
          planned: false,
          unavailable_message: nil,
          root_available: false
        )
      end

      def cash_command
        Command.new(
          key: :cash,
          canonical: "/cash",
          aliases: %w[cs],
          legacy_aliases: [],
          description: "Cash tender on a sale",
          permission_keys: [ "pos.tenders.cash" ],
          transaction_required: true,
          register_session_required: true,
          handler: :tender_cash,
          planned: false,
          unavailable_message: nil,
          root_available: false
        )
      end

      def card_command
        Command.new(
          key: :card,
          canonical: "/card",
          aliases: %w[cd],
          legacy_aliases: [],
          description: "Card tender on a sale",
          permission_keys: [ "pos.tenders.card" ],
          transaction_required: true,
          register_session_required: true,
          handler: :tender_card,
          planned: false,
          unavailable_message: nil,
          root_available: false
        )
      end

      def check_command
        Command.new(
          key: :check,
          canonical: "/check",
          aliases: %w[ck],
          legacy_aliases: [],
          description: "Check tender on a sale",
          permission_keys: [ "pos.tenders.check" ],
          transaction_required: true,
          register_session_required: true,
          handler: :tender_check,
          planned: false,
          unavailable_message: nil,
          root_available: false
        )
      end

      def storecredit_command
        Command.new(
          key: :storecredit,
          canonical: "/storecredit",
          aliases: %w[sc],
          legacy_aliases: [],
          description: "Store credit tender on a sale",
          permission_keys: [ "pos.tenders.store_credit" ],
          transaction_required: true,
          register_session_required: true,
          handler: :tender_store_credit,
          planned: false,
          unavailable_message: nil,
          root_available: false
        )
      end

      def hold_command
        Command.new(
          key: :hold,
          canonical: "/hold",
          aliases: %w[ho],
          legacy_aliases: [],
          description: "Suspend current transaction",
          permission_keys: [ "pos.transactions.suspend" ],
          transaction_required: true,
          register_session_required: true,
          handler: :hold,
          planned: false,
          unavailable_message: nil,
          root_available: false
        )
      end

      def session_command
        Command.new(
          key: :session,
          canonical: "/session",
          aliases: %w[se],
          legacy_aliases: [],
          description: "Register session summary",
          permission_keys: [ "pos.register_sessions.view" ],
          transaction_required: false,
          register_session_required: true,
          handler: :session_drawer,
          planned: false,
          unavailable_message: nil,
          root_available: true
        )
      end

      def cashdrop_command
        Command.new(
          key: :cashdrop,
          canonical: "/cashdrop",
          aliases: %w[dp drop],
          legacy_aliases: [],
          description: "Cash drop to safe",
          permission_keys: [ "pos.cash_movements.create" ],
          transaction_required: false,
          register_session_required: true,
          handler: :cash_drop,
          planned: true,
          unavailable_message: CASH_DROP_UNAVAILABLE_MESSAGE,
          root_available: true
        )
      end

      def cashin_command
        Command.new(
          key: :cashin,
          canonical: "/cashin",
          aliases: %w[ci],
          legacy_aliases: [],
          description: "Miscellaneous cash in",
          permission_keys: [ "pos.cash_movements.create" ],
          transaction_required: false,
          register_session_required: true,
          handler: :cash_in,
          planned: false,
          unavailable_message: nil,
          root_available: true
        )
      end

      def cashout_command
        Command.new(
          key: :cashout,
          canonical: "/cashout",
          aliases: %w[co],
          legacy_aliases: [],
          description: "Miscellaneous cash out",
          permission_keys: [ "pos.cash_movements.create" ],
          transaction_required: false,
          register_session_required: true,
          handler: :cash_out,
          planned: false,
          unavailable_message: nil,
          root_available: true
        )
      end

      def close_command
        Command.new(
          key: :close,
          canonical: "/close",
          aliases: %w[cl],
          legacy_aliases: [],
          description: "Close register workflow",
          permission_keys: [ "pos.register_sessions.close" ],
          transaction_required: false,
          register_session_required: true,
          handler: :close_register,
          planned: false,
          unavailable_message: nil,
          root_available: true
        )
      end

      def reports_command
        Command.new(
          key: :reports,
          canonical: "/reports",
          aliases: %w[rp],
          legacy_aliases: [],
          description: "Navigate to reports",
          permission_keys: [ "pos.reports.view" ],
          transaction_required: false,
          register_session_required: true,
          handler: :reports,
          planned: false,
          unavailable_message: nil,
          root_available: true
        )
      end

      def drawer_command
        Command.new(
          key: :drawer,
          canonical: "/drawer",
          aliases: %w[dr],
          legacy_aliases: [],
          description: "Cash drawer action",
          permission_keys: [ "pos.cash_movements.create" ],
          transaction_required: false,
          register_session_required: true,
          handler: :drawer_action,
          planned: false,
          unavailable_message: nil,
          root_available: true
        )
      end
    end
  end
end
