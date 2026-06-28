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

      def build(**attrs)
        defaults = {
          legacy_aliases: [],
          permission_keys: [],
          transaction_required: false,
          register_session_required: true,
          planned: false,
          unavailable_message: CommandRouteBuilder::NOT_YET_AVAILABLE_MESSAGE,
          unavailable_action: :message,
          root_implemented: false,
          transaction_implemented: false,
          root_available: true,
          root_unavailable_message: nil,
          transaction_unavailable_message: nil
        }
        Command.new(**defaults.merge(attrs))
      end

      def help_command
        build(
          key: :help,
          canonical: "/help",
          aliases: %w[/? ?],
          description: "Show command help",
          register_session_required: false,
          handler: :help,
          root_implemented: true,
          transaction_implemented: true
        )
      end

      def customer_command
        build(
          key: :customer,
          canonical: "/customer",
          aliases: %w[cu],
          description: "Customer lookup",
          permission_keys: [ "pos.access" ],
          handler: :customer_lookup
        )
      end

      def openring_command
        build(
          key: :openring,
          canonical: "/openring",
          aliases: %w[op],
          legacy_aliases: %w[open],
          description: "Open-ring sale",
          permission_keys: [ "pos.lines.add.open_ring" ],
          handler: :open_ring,
          root_implemented: true,
          transaction_implemented: true
        )
      end

      def linediscount_command
        build(
          key: :linediscount,
          canonical: "/linediscount",
          aliases: %w[ld],
          legacy_aliases: %w[d],
          description: "Line discount",
          permission_keys: [ "pos.discounts.line.apply" ],
          transaction_required: true,
          handler: :line_discount,
          root_available: false,
          transaction_implemented: true
        )
      end

      def discount_command
        build(
          key: :discount,
          canonical: "/discount",
          aliases: %w[di],
          legacy_aliases: %w[dt],
          description: "Transaction discount",
          permission_keys: [ "pos.discounts.transaction.apply" ],
          transaction_required: true,
          handler: :transaction_discount,
          root_available: false,
          transaction_implemented: true
        )
      end

      def taxexempt_command
        build(
          key: :taxexempt,
          canonical: "/taxexempt",
          aliases: %w[tx],
          description: "Tax exemption",
          permission_keys: [ "pos.tax_exemptions.apply" ],
          transaction_required: true,
          handler: :tax_exempt,
          root_available: false
        )
      end

      def giftcard_command
        build(
          key: :giftcard,
          canonical: "/giftcard",
          aliases: %w[gc],
          description: "Gift card issue or reload",
          permission_keys: [ "pos.gift_cards.issue" ],
          handler: :gift_card_modal,
          root_implemented: true,
          transaction_implemented: true
        )
      end

      def giftredeem_command
        build(
          key: :giftredeem,
          canonical: "/giftredeem",
          aliases: %w[gr],
          description: "Gift card redemption tender",
          permission_keys: [ "pos.tenders.gift_card" ],
          transaction_required: true,
          handler: :gift_redeem,
          root_available: false,
          transaction_implemented: true
        )
      end

      def balance_command
        build(
          key: :balance,
          canonical: "/balance",
          aliases: %w[bl],
          description: "Stored value balance inquiry",
          permission_keys: [ "pos.tenders.gift_card", "pos.tenders.store_credit" ],
          handler: :balance_inquiry,
          root_implemented: true,
          transaction_implemented: true
        )
      end

      def return_command
        build(
          key: :return,
          canonical: "/return",
          aliases: %w[rt],
          description: "Return workflow",
          permission_keys: [ "pos.returns.receipted" ],
          handler: :return_drawer,
          root_implemented: true,
          transaction_implemented: true
        )
      end

      def pickup_command
        build(
          key: :pickup,
          canonical: "/pickup",
          aliases: %w[pu],
          description: "Customer pickup workflow",
          permission_keys: [ "pos.access" ],
          handler: :pickup_drawer,
          root_implemented: true,
          transaction_implemented: true
        )
      end

      def tender_command
        build(
          key: :tender,
          canonical: "/tender",
          aliases: %w[tn],
          description: "Settlement modal",
          permission_keys: [ "pos.tenders.cash", "pos.tenders.card", "pos.tenders.check", "pos.tenders.gift_card", "pos.tenders.store_credit" ],
          transaction_required: true,
          handler: :settlement_modal,
          root_available: false,
          transaction_implemented: true
        )
      end

      def cash_command
        build(
          key: :cash,
          canonical: "/cash",
          aliases: %w[cs],
          description: "Cash tender on a sale",
          permission_keys: [ "pos.tenders.cash" ],
          transaction_required: true,
          handler: :tender_cash,
          root_available: false,
          transaction_implemented: true
        )
      end

      def card_command
        build(
          key: :card,
          canonical: "/card",
          aliases: %w[cd],
          description: "Card tender on a sale",
          permission_keys: [ "pos.tenders.card" ],
          transaction_required: true,
          handler: :tender_card,
          root_available: false,
          transaction_implemented: true
        )
      end

      def check_command
        build(
          key: :check,
          canonical: "/check",
          aliases: %w[ck],
          description: "Check tender on a sale",
          permission_keys: [ "pos.tenders.check" ],
          transaction_required: true,
          handler: :tender_check,
          root_available: false,
          transaction_implemented: true
        )
      end

      def storecredit_command
        build(
          key: :storecredit,
          canonical: "/storecredit",
          aliases: %w[sc],
          description: "Store credit tender on a sale",
          permission_keys: [ "pos.tenders.store_credit" ],
          transaction_required: true,
          handler: :tender_store_credit,
          root_available: false,
          transaction_implemented: true
        )
      end

      def hold_command
        build(
          key: :hold,
          canonical: "/hold",
          aliases: %w[ho],
          description: "Suspend current transaction",
          permission_keys: [ "pos.transactions.suspend" ],
          transaction_required: true,
          handler: :hold,
          root_available: false
        )
      end

      def session_command
        build(
          key: :session,
          canonical: "/session",
          aliases: %w[se],
          description: "Register session summary",
          permission_keys: [ "pos.register_sessions.view" ],
          handler: :session_drawer,
          root_implemented: true,
          transaction_implemented: true
        )
      end

      def cashdrop_command
        build(
          key: :cashdrop,
          canonical: "/cashdrop",
          aliases: %w[dp drop],
          description: "Cash drop to safe",
          permission_keys: [ "pos.cash_movements.create" ],
          handler: :cash_drop,
          planned: true,
          unavailable_message: CASH_DROP_UNAVAILABLE_MESSAGE
        )
      end

      def cashin_command
        build(
          key: :cashin,
          canonical: "/cashin",
          aliases: %w[ci],
          description: "Miscellaneous cash in",
          permission_keys: [ "pos.cash_movements.create" ],
          handler: :cash_in,
          root_implemented: true,
          transaction_implemented: true
        )
      end

      def cashout_command
        build(
          key: :cashout,
          canonical: "/cashout",
          aliases: %w[co],
          description: "Miscellaneous cash out",
          permission_keys: [ "pos.cash_movements.create" ],
          handler: :cash_out,
          root_implemented: true,
          transaction_implemented: true
        )
      end

      def close_command
        build(
          key: :close,
          canonical: "/close",
          aliases: %w[cl],
          description: "Close register workflow",
          permission_keys: [ "pos.register_sessions.close" ],
          handler: :close_register,
          root_implemented: true,
          transaction_implemented: true
        )
      end

      def reports_command
        build(
          key: :reports,
          canonical: "/reports",
          aliases: %w[rp],
          description: "Navigate to reports",
          permission_keys: [ "pos.reports.view" ],
          handler: :reports,
          root_implemented: true,
          transaction_implemented: true
        )
      end

      def drawer_command
        build(
          key: :drawer,
          canonical: "/drawer",
          aliases: %w[dr],
          description: "Cash drawer action",
          permission_keys: [ "pos.cash_movements.create" ],
          handler: :drawer_action,
          root_implemented: true,
          transaction_implemented: true
        )
      end
    end
  end
end
