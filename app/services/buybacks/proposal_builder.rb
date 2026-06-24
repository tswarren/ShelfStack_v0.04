# frozen_string_literal: true

module Buybacks
  class ProposalBuilder
    Result = Data.define(:session, :offered_lines, :not_accepted_lines, :totals) do
      def lines
        offered_lines
      end
    end

    def self.build(session)
      new(session).build
    end

    def initialize(session)
      @session = session
    end

    def build
      all_lines = session.buyback_lines.order(:line_number)
      offered_lines = all_lines.reject(&:store_rejected?)
      not_accepted_lines = all_lines.select(&:store_rejected?)
      Result.new(
        session: session,
        offered_lines: offered_lines,
        not_accepted_lines: not_accepted_lines,
        totals: {
          resale_cents: offered_lines.sum { |l| l.proposed_resale_price_cents.to_i },
          cash_offer_cents: offered_lines.sum { |l| l.proposed_cash_offer_cents.to_i },
          trade_credit_offer_cents: offered_lines.sum { |l| l.proposed_trade_credit_offer_cents.to_i }
        }
      )
    end

    private

    attr_reader :session
  end
end
