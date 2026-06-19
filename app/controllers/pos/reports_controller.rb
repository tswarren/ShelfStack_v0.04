# frozen_string_literal: true

require "csv"

module Pos
  class ReportsController < BaseController
    before_action -> { authorize_pos!("pos.reports.view") }

    def index
    end

    def sales
      authorize_pos!("pos.reports.sales")
      @transactions = PosTransaction.completed_records.where(store: pos_store).order(completed_at: :desc).limit(100)

      respond_to do |format|
        format.html
        format.csv do
          authorize_pos!("pos.reports.export")
          send_data sales_csv(@transactions), filename: "pos-sales-#{Date.current}.csv", type: "text/csv"
        end
      end
    end

    def returns
      authorize_pos!("pos.reports.returns")
      @transactions = PosTransaction.completed_records
        .where(store: pos_store, transaction_type: %w[return exchange])
        .order(completed_at: :desc)
        .limit(100)

      respond_to do |format|
        format.html
        format.csv do
          authorize_pos!("pos.reports.export")
          send_data returns_csv(@transactions), filename: "pos-returns-#{Date.current}.csv", type: "text/csv"
        end
      end
    end

    def drawer
      authorize_pos!("pos.reports.drawer")
      @sessions = PosRegisterSession.where(store: pos_store).order(opened_at: :desc).limit(20)
      @session = params[:session_id].present? ? PosRegisterSession.where(store: pos_store).find_by(id: params[:session_id]) : current_register_session
      @summary = @session && Pos::RegisterSessionSummary.for(@session)
    end

    private

    def sales_csv(transactions)
      CSV.generate do |csv|
        csv << %w[transaction_number completed_at type subtotal_cents tax_cents total_cents cashier]
        transactions.each do |transaction|
          csv << [
            transaction.transaction_number,
            transaction.completed_at,
            transaction.transaction_type,
            transaction.subtotal_cents,
            transaction.tax_cents,
            transaction.total_cents,
            transaction.cashier_user.username
          ]
        end
      end
    end

    def returns_csv(transactions)
      CSV.generate do |csv|
        csv << %w[transaction_number completed_at type total_cents cashier]
        transactions.each do |transaction|
          csv << [
            transaction.transaction_number,
            transaction.completed_at,
            transaction.transaction_type,
            transaction.total_cents,
            transaction.cashier_user.username
          ]
        end
      end
    end
  end
end
