# frozen_string_literal: true

module Pos
  class RegisterSessionSummary
    Summary = Data.define(
      :opening_cash_cents,
      :paid_in_cents,
      :paid_out_cents,
      :net_cash_tender_cents,
      :expected_closing_cash_cents,
      :completed_transaction_count,
      :suspended_transaction_count
    )

    def self.for(session)
      new(session).call
    end

    def initialize(session)
      @session = session
    end

    def call
      paid_in = session.pos_cash_movements.where(movement_type: "paid_in").sum(:amount_cents)
      paid_out = session.pos_cash_movements.where(movement_type: "paid_out").sum(:amount_cents)
      net_cash = PosTender
        .joins(:pos_transaction)
        .where(pos_transactions: { pos_register_session_id: session.id, status: "completed" })
        .where(tender_type: "cash")
        .sum(:amount_cents)

      Summary.new(
        opening_cash_cents: session.opening_cash_cents,
        paid_in_cents: paid_in,
        paid_out_cents: paid_out,
        net_cash_tender_cents: net_cash,
        expected_closing_cash_cents: session.opening_cash_cents + paid_in - paid_out + net_cash,
        completed_transaction_count: session.pos_transactions.completed_records.count,
        suspended_transaction_count: PosTransaction.suspended.where(workstation: session.workstation).count
      )
    end

    private

    attr_reader :session
  end
end
