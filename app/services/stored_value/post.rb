# frozen_string_literal: true

module StoredValue
  class Post
    class Error < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(
      account:,
      store:,
      actor:,
      entry_type:,
      amount_delta_cents:,
      reason_code: nil,
      source: nil,
      reverses_entry: nil,
      notes: nil,
      posted_at: Time.current,
      audit_event_name: nil
    )
      @account = account
      @store = store
      @actor = actor
      @entry_type = entry_type
      @amount_delta_cents = amount_delta_cents
      @reason_code = reason_code
      @source = source
      @reverses_entry = reverses_entry
      @notes = notes
      @posted_at = posted_at
      @audit_event_name = audit_event_name
    end

    def call
      raise Error, "Account is not active" unless account.postable?

      entry = nil
      account.with_lock do
        balance_after = BalanceUpdater.apply!(account: account, amount_delta_cents: amount_delta_cents)
        account.reload

        entry = StoredValueLedgerEntry.create!(
          stored_value_account: account,
          store: store,
          entry_type: entry_type,
          amount_delta_cents: amount_delta_cents,
          balance_after_cents: balance_after,
          reason_code: reason_code,
          reverses_entry: reverses_entry,
          source: source,
          notes: notes,
          posted_at: posted_at,
          created_by_user: actor
        )
      end

      record_audit!(entry) if audit_event_name.present?
      entry
    rescue BalanceUpdater::NegativeBalanceError => e
      raise Error, e.message
    end

    private

    attr_reader :account, :store, :actor, :entry_type, :amount_delta_cents,
                :reason_code, :source, :reverses_entry, :notes, :posted_at, :audit_event_name

    def record_audit!(entry)
      with_current_store do
        AuditEvents.record!(
          actor: actor,
          event_name: audit_event_name,
          auditable: entry,
          source: account,
          details: {
            "store_id" => store.id,
            "stored_value_account_id" => account.id,
            "entry_type" => entry_type,
            "amount_delta_cents" => amount_delta_cents,
            "balance_after_cents" => entry.balance_after_cents
          }
        )
      end
    end

    def with_current_store
      previous_store = Current.store
      Current.store = store
      yield
    ensure
      Current.store = previous_store
    end
  end
end
