# frozen_string_literal: true

module Pos
  class SuspendedTransactionsLookup
    def self.for_workstation(store:, workstation:)
      PosTransaction.suspended
        .includes(:pos_transaction_lines, :cashier_user)
        .where(store: store, workstation: workstation)
        .order(suspended_at: :desc)
    end
  end
end
