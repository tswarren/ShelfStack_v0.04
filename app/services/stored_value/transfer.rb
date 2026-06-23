# frozen_string_literal: true

module StoredValue
  class Transfer
    class Error < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(from_account:, to_account:, store:, actor:, amount_cents:, reason_code:, notes: nil)
      @from_account = from_account
      @to_account = to_account
      @store = store
      @actor = actor
      @amount_cents = amount_cents
      @reason_code = reason_code
      @notes = notes
    end

    def call
      previous_store = Current.store
      raise Error, "Amount must be positive" unless amount_cents.positive?
      raise Error, "Reason code is required" if reason_code.blank?
      raise Error, "Source and destination accounts must differ" if from_account.id == to_account.id
      raise Error, "Source account is not active" unless from_account.postable?
      raise Error, "Destination account is not active" unless to_account.postable?

      transfer = nil
      ActiveRecord::Base.transaction do
        out_entry = Post.call(
          account: from_account,
          store: store,
          actor: actor,
          entry_type: "transfer_out",
          amount_delta_cents: -amount_cents,
          reason_code: reason_code,
          notes: notes
        )

        in_entry = Post.call(
          account: to_account,
          store: store,
          actor: actor,
          entry_type: "transfer_in",
          amount_delta_cents: amount_cents,
          reason_code: reason_code,
          notes: notes
        )

        transfer = StoredValueTransfer.create!(
          from_account: from_account,
          to_account: to_account,
          amount_cents: amount_cents,
          transfer_out_entry: out_entry,
          transfer_in_entry: in_entry,
          reason_code: reason_code,
          created_by_user: actor
        )

        Current.store = store
        AuditEvents.record!(
          actor: actor,
          event_name: "stored_value.ledger.transferred",
          auditable: transfer,
          details: {
            "store_id" => store.id,
            "from_account_id" => from_account.id,
            "to_account_id" => to_account.id,
            "amount_cents" => amount_cents
          }
        )
      end
      transfer
    ensure
      Current.store = previous_store
    end

    private

    attr_reader :from_account, :to_account, :store, :actor, :amount_cents, :reason_code, :notes
  end
end
