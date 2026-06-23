# frozen_string_literal: true

module StoredValue
  class VoidEntry
    class Error < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(entry:, store:, actor:, reason_code:, notes: nil)
      @entry = entry
      @store = store
      @actor = actor
      @reason_code = reason_code
      @notes = notes
    end

    def call
      raise Error, "Reason code is required" if reason_code.blank?
      raise Error, "Entry is already voided" if entry.void_reversal.present?

      Post.call(
        account: entry.stored_value_account,
        store: store,
        actor: actor,
        entry_type: "void_reversal",
        amount_delta_cents: -entry.amount_delta_cents,
        reason_code: reason_code,
        reverses_entry: entry,
        notes: notes,
        audit_event_name: "stored_value.ledger.voided"
      )
    end

    private

    attr_reader :entry, :store, :actor, :reason_code, :notes
  end
end
