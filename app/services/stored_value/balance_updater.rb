# frozen_string_literal: true

module StoredValue
  class BalanceUpdater
    class NegativeBalanceError < StandardError; end

    def self.apply!(account:, amount_delta_cents:)
      new(account:, amount_delta_cents:).apply!
    end

    def initialize(account:, amount_delta_cents:)
      @account = account
      @amount_delta_cents = amount_delta_cents
    end

    def apply!
      prior_balance = account.current_balance_cents
      new_balance = prior_balance + amount_delta_cents
      raise NegativeBalanceError, "Balance cannot go negative" if new_balance.negative?

      account.update!(current_balance_cents: new_balance)
      new_balance
    end

    private

    attr_reader :account, :amount_delta_cents
  end
end
