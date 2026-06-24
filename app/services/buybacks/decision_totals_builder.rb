# frozen_string_literal: true

module Buybacks
  class DecisionTotalsBuilder
    Result = Data.define(
      :accepted_cash_cents,
      :accepted_trade_credit_cents,
      :donation_count,
      :declined_count,
      :rejected_count,
      :recycle_count
    )

    def self.build(session)
      new(session).build
    end

    def initialize(session)
      @session = session
    end

    def build
      lines = session.buyback_lines.to_a
      accepted = lines.select { |l| l.outcome == "accepted_by_customer" }
      donated = lines.select(&:donation?)
      declined = lines.select { |l| l.outcome == "declined_by_customer" }
      rejected = lines.select(&:store_rejected?)
      recycled = lines.select { |l| l.outcome == "recycle_with_permission" }

      Result.new(
        accepted_cash_cents: accepted.sum { |l| l.proposed_cash_offer_cents.to_i },
        accepted_trade_credit_cents: accepted.sum { |l| l.proposed_trade_credit_offer_cents.to_i },
        donation_count: donated.size,
        declined_count: declined.size,
        rejected_count: rejected.size,
        recycle_count: recycled.size
      )
    end

    private

    attr_reader :session
  end
end
