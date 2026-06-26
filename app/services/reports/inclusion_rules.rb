# frozen_string_literal: true

module Reports
  # Query scopes and inclusion helpers for operational reports (Phase 9b).
  # See docs/specifications/reporting-semantics.md
  class InclusionRules
    def self.pos_sales_transactions(store: nil)
      scope = PosTransaction.completed_records
      scope = scope.where(store: store) if store.present?
      scope
    end

    def self.pos_excluded_from_sales(store: nil)
      scope = PosTransaction.where(status: %w[draft suspended cancelled voided])
      scope = scope.where(store: store) if store.present?
      scope
    end

    def self.buyback_reportable_sessions(store: nil)
      scope = BuybackSession.where(status: %w[completed voided])
      scope = scope.where(store: store) if store.present?
      scope
    end

    def self.buyback_excluded_sessions(store: nil)
      scope = BuybackSession.where(status: %w[draft quoted decision cancelled])
      scope = scope.where(store: store) if store.present?
      scope
    end

    def self.inventory_ledger_entries(store: nil)
      scope = InventoryLedgerEntry.joins(:inventory_posting)
      scope = scope.where(store: store) if store.present?
      scope
    end

    def self.stored_value_ledger_entries(store: nil)
      scope = StoredValueLedgerEntry.all
      scope = scope.where(store: store) if store.present?
      scope
    end
  end
end
