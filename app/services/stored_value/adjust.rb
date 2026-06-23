# frozen_string_literal: true

module StoredValue
  class Adjust
    class Error < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(account:, store:, actor:, amount_delta_cents:, reason_code:, notes: nil)
      @account = account
      @store = store
      @actor = actor
      @amount_delta_cents = amount_delta_cents
      @reason_code = reason_code
      @notes = notes
    end

    def call
      raise Error, "Adjustment amount cannot be zero" if amount_delta_cents.zero?
      raise Error, "Reason code is required" if reason_code.blank?

      Post.call(
        account: account,
        store: store,
        actor: actor,
        entry_type: "adjust",
        amount_delta_cents: amount_delta_cents,
        reason_code: reason_code,
        notes: notes,
        audit_event_name: "stored_value.ledger.adjusted"
      )
    end

    private

    attr_reader :account, :store, :actor, :amount_delta_cents, :reason_code, :notes
  end
end
