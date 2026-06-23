# frozen_string_literal: true

module StoredValue
  class BalanceIntegrityCheck
    Mismatch = Data.define(:stored_value_account_id, :cached_balance_cents, :ledger_balance_cents)

    Result = Data.define(:passed, :mismatches)

    def self.call(actor: nil)
      new(actor:).call
    end

    def initialize(actor: nil)
      @actor = actor
    end

    def call
      mismatches = []

      ledger_sums.each do |row|
        account = StoredValueAccount.find(row.stored_value_account_id)
        cached = account.current_balance_cents
        ledger = row.total_delta.to_i
        next if cached == ledger

        mismatches << Mismatch.new(
          stored_value_account_id: row.stored_value_account_id,
          cached_balance_cents: cached,
          ledger_balance_cents: ledger
        )
      end

      StoredValueAccount.find_each do |account|
        next if ledger_sums_map.key?(account.id)

        next if account.current_balance_cents.zero?

        mismatches << Mismatch.new(
          stored_value_account_id: account.id,
          cached_balance_cents: account.current_balance_cents,
          ledger_balance_cents: 0
        )
      end

      if (audit_actor = actor || User.find_by(username: ShelfStack::SYSTEM_USERNAME))
        AuditEvents.record!(
          actor: audit_actor,
          event_name: "stored_value.integrity_check",
          details: {
            "mismatch_count" => mismatches.size,
            "passed" => mismatches.empty?
          }
        )
      end

      Result.new(passed: mismatches.empty?, mismatches: mismatches)
    end

    private

    attr_reader :actor

    def ledger_sums
      @ledger_sums ||= StoredValueLedgerEntry
        .select("stored_value_account_id, SUM(amount_delta_cents) AS total_delta")
        .group(:stored_value_account_id)
        .to_a
    end

    def ledger_sums_map
      @ledger_sums_map ||= ledger_sums.index_by(&:stored_value_account_id)
    end
  end
end
