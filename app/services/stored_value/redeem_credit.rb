# frozen_string_literal: true

module StoredValue
  class RedeemCredit
    class Error < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(account:, store:, actor:, amount_cents:, notes: nil, source: nil)
      @account = account
      @store = store
      @actor = actor
      @amount_cents = amount_cents
      @notes = notes
      @source = source
    end

    def call
      raise Error, "Amount must be positive" unless amount_cents.positive?

      Post.call(
        account: account,
        store: store,
        actor: actor,
        entry_type: "redeem",
        amount_delta_cents: -amount_cents,
        source: source,
        notes: notes,
        audit_event_name: "stored_value.ledger.redeemed"
      )
    end

    private

    attr_reader :account, :store, :actor, :amount_cents, :notes, :source
  end
end
