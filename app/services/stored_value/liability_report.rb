# frozen_string_literal: true

module StoredValue
  class LiabilityReport
    BalanceRow = Data.define(:account_type, :issuing_store_id, :issuing_store_name, :account_count, :total_balance_cents)
    ActivityRow = Data.define(:entry_type, :entry_count, :total_amount_cents)

    Result = Data.define(:balance_rows, :activity_rows, :total_liability_cents)

    def self.call(store: nil, date_range: nil)
      new(store:, date_range:).call
    end

    def initialize(store: nil, date_range: nil)
      @store = store
      @date_range = date_range
    end

    def call
      balance_scope = StoredValueAccount.active_records.where("current_balance_cents > 0")
      balance_scope = balance_scope.where(issuing_store: store) if store

      balance_rows = balance_scope
        .joins(:issuing_store)
        .group(:account_type, :issuing_store_id, "stores.name")
        .pluck(
          :account_type,
          :issuing_store_id,
          "stores.name",
          Arel.sql("COUNT(*)"),
          Arel.sql("SUM(current_balance_cents)")
        )
        .map do |account_type, issuing_store_id, store_name, account_count, total_balance_cents|
          BalanceRow.new(
            account_type: account_type,
            issuing_store_id: issuing_store_id,
            issuing_store_name: store_name,
            account_count: account_count,
            total_balance_cents: total_balance_cents
          )
        end

      activity_scope = StoredValueLedgerEntry.all
      activity_scope = activity_scope.where(store: store) if store
      if date_range.present?
        activity_scope = activity_scope.where(posted_at: date_range)
      end

      activity_rows = activity_scope
        .group(:entry_type)
        .pluck(:entry_type, Arel.sql("COUNT(*)"), Arel.sql("SUM(amount_delta_cents)"))
        .map do |entry_type, entry_count, total_amount_cents|
          ActivityRow.new(
            entry_type: entry_type,
            entry_count: entry_count,
            total_amount_cents: total_amount_cents
          )
        end

      total_liability_cents = balance_rows.sum(&:total_balance_cents)

      Result.new(
        balance_rows: balance_rows,
        activity_rows: activity_rows,
        total_liability_cents: total_liability_cents
      )
    end

    private

    attr_reader :store, :date_range
  end
end
