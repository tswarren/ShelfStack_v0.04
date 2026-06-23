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
      return [] unless reversal_needed?

      reason_code = StoredValueReasonCode.find_by!(reason_key: "void_reversal")
      entries = []

      reverse_tender_entries!(reason_code, entries)
      reverse_gift_card_sale_entries!(reason_code, entries)

      entries
    end

    private

    attr_reader :transaction, :actor, :pos_void, :store

    def reversal_needed?
      transaction.pos_tenders.settlement_rows.any?(&:stored_value_tender?) ||
        transaction.pos_transaction_lines.any?(&:gift_card_sale_line?)
    end

    def reverse_tender_entries!(reason_code, entries)
      original_tenders = transaction.pos_tenders.settlement_rows
      return if original_tenders.none?(&:stored_value_tender?)

      original_tenders.select(&:stored_value_tender?).each do |tender|
        reverse_entries_for_source!(source: tender, reason_code:, entries:, details: {
          "pos_tender_id" => tender.id
        })
      end
    end

    def reverse_gift_card_sale_entries!(reason_code, entries)
      transaction.pos_transaction_lines.select(&:gift_card_sale_line?).each do |line|
        reverse_entries_for_source!(source: line, reason_code:, entries:, details: {
          "pos_transaction_line_id" => line.id
        })
      end
    end

    def reverse_entries_for_source!(source:, reason_code:, entries:, details:)
      ledger_entries = StoredValueLedgerEntry.where(source: source).posted_order.reverse
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
            "reverses_entry_id" => entry.id,
            "amount_delta_cents" => reversal.amount_delta_cents
          }.merge(details)
        )
      end
    end
  end
end
