# frozen_string_literal: true

module Pos
  class ReverseStoredValueLedger
    Error = Class.new(StandardError)

    def self.call!(transaction:, actor:, pos_void:, store: nil)
      new(transaction:, actor:, pos_void:, store:).call!
    end

    def initialize(transaction:, actor:, pos_void:, store: nil)
      @transaction = transaction
      @actor = actor
      @pos_void = pos_void
      @store = store || transaction.store
    end

    def call!
      original_tenders = transaction.pos_tenders.settlement_rows
      return [] if original_tenders.none?(&:stored_value_tender?)

      reason_code = StoredValueReasonCode.find_by!(reason_key: "void_reversal")
      entries = []

      original_tenders.select(&:stored_value_tender?).each do |tender|
        ledger_entries = StoredValueLedgerEntry.where(source: tender).posted_order.reverse
        ledger_entries.each do |entry|
          next if entry.void_reversal.present?

          reversal = StoredValue::Post.call(
            account: entry.stored_value_account,
            store: store,
            actor: actor,
            entry_type: "void_reversal",
            amount_delta_cents: -entry.amount_delta_cents,
            reason_code: reason_code,
            reverses_entry: entry,
            source: pos_void,
            notes: "POS void reversal for transaction #{transaction.transaction_number}",
            audit_event_name: "stored_value.ledger.voided"
          )
          entries << reversal

          AuditEvents.record!(
            actor: actor,
            event_name: "pos.stored_value.void_reversed",
            auditable: reversal,
            source: pos_void,
            details: {
              "store_id" => store.id,
              "pos_transaction_id" => transaction.id,
              "pos_tender_id" => tender.id,
              "reverses_entry_id" => entry.id,
              "amount_delta_cents" => reversal.amount_delta_cents
            }
          )
        end
      end

      entries
    end

    private

    attr_reader :transaction, :actor, :pos_void, :store
  end
end
