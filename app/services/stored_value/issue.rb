# frozen_string_literal: true

module StoredValue
  class Issue
    class Error < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(account:, store:, actor:, amount_cents:, reason_code:, notes: nil, source: nil)
      @account = account
      @store = store
      @actor = actor
      @amount_cents = amount_cents
      @reason_code = reason_code
      @notes = notes
      @source = source
    end

    def call
      raise Error, "Amount must be positive" unless amount_cents.positive?
      raise Error, "Reason code is required" if reason_code.blank?

      Post.call(
        account: account,
        store: store,
        actor: actor,
        entry_type: "issue",
        amount_delta_cents: amount_cents,
        reason_code: reason_code,
        source: source,
        notes: notes,
        audit_event_name: "stored_value.ledger.issued"
      )
    end

    private

    attr_reader :account, :store, :actor, :amount_cents, :reason_code, :notes, :source
  end
end
