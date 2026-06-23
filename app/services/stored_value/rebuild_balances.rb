# frozen_string_literal: true

module StoredValue
  class RebuildBalances
    def self.call(actor: nil)
      new(actor:).call
    end

    def initialize(actor: nil)
      @actor = actor
    end

    def call
      rebuilt = 0

      StoredValueAccount.find_each do |account|
        ledger_total = StoredValueLedgerEntry
          .where(stored_value_account_id: account.id)
          .sum(:amount_delta_cents)

        next if account.current_balance_cents == ledger_total

        account.update!(current_balance_cents: ledger_total)
        rebuilt += 1
      end

      AuditEvents.record!(
        actor: actor || User.find_by!(username: ShelfStack::SYSTEM_USERNAME),
        event_name: "stored_value.balance_rebuild",
        details: { "accounts_rebuilt" => rebuilt }
      )

      rebuilt
    end

    private

    attr_reader :actor
  end
end
