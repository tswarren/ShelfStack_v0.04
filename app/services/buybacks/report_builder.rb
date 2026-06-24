# frozen_string_literal: true

module Buybacks
  class ReportBuilder
    Summary = Data.define(
      :session_count,
      :completed_count,
      :voided_count,
      :cash_paid_cents,
      :trade_credit_issued_cents,
      :donation_count,
      :override_count,
      :needs_review_count
    )

    def self.summary(store:, date_range: nil)
      new(store:, date_range:).summary
    end

    def self.activity(store:, date_range: nil, limit: 100)
      new(store:, date_range:).activity(limit:)
    end

    def initialize(store:, date_range: nil)
      @store = store
      @date_range = date_range
    end

    def summary
      scope = BuybackSession.for_store(store)
      scope = scope.where(completed_at: date_range) if date_range.present?

      completed = scope.where(status: "completed")
      voided = scope.where(status: "voided")

      Summary.new(
        session_count: scope.count,
        completed_count: completed.count,
        voided_count: voided.count,
        cash_paid_cents: completed.where(payout_mode: "cash").sum(:accepted_payout_cents),
        trade_credit_issued_cents: completed.where(payout_mode: "trade_credit").sum(:accepted_payout_cents),
        donation_count: completed.where(payout_mode: "no_value_donation").count,
        override_count: BuybackLine.joins(:buyback_session).merge(scope)
          .where("buyback_lines.resale_price_overridden = ? OR buyback_lines.offer_overridden = ?", true, true).count,
        needs_review_count: CatalogItem.where(source: "buyback_intake", needs_review: true, active: true).count
      )
    end

    def activity(limit: 100)
      scope = BuybackSession.for_store(store).order(created_at: :desc)
      scope = scope.where(created_at: date_range) if date_range.present?
      scope.limit(limit)
    end

    private

    attr_reader :store, :date_range
  end
end
