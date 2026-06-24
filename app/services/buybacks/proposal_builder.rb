# frozen_string_literal: true

module Buybacks
  class ProposalBuilder
    Result = Data.define(:session, :lines, :totals)

    def self.build(session)
      new(session).build
    end

    def initialize(session)
      @session = session
    end

    def build
      lines = session.buyback_lines.order(:line_number).reject(&:store_rejected?)
      Result.new(
        session: session,
        lines: lines,
        totals: {
          resale_cents: lines.sum { |l| l.proposed_resale_price_cents.to_i },
          cash_offer_cents: lines.sum { |l| l.proposed_cash_offer_cents.to_i },
          trade_credit_offer_cents: lines.sum { |l| l.proposed_trade_credit_offer_cents.to_i }
        }
      )
    end

    private

    attr_reader :session
  end
end
