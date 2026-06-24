# frozen_string_literal: true

module Buybacks
  class ReceiptBuilder
    Result = Data.define(:session, :lines, :identifier_display, :payout_label)

    def self.build(session)
      new(session).build
    end

    def initialize(session)
      @session = session
    end

    def build
      identifier = session.stored_value_account&.stored_value_identifiers&.active_records&.order(:id)&.first
      Result.new(
        session: session,
        lines: session.buyback_lines.order(:line_number),
        identifier_display: identifier&.display_value_masked,
        payout_label: payout_label_for(session)
      )
    end

    private

    attr_reader :session

    def payout_label_for(session)
      case session.payout_mode
      when "cash" then "Cash"
      when "trade_credit" then "Trade credit"
      when "no_value_donation" then "No-value donation"
      else "—"
      end
    end
  end
end
