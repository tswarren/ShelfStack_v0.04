# frozen_string_literal: true

module Pos
  class StoredValueIssuanceSlips
    SlipRef = Data.define(:ledger_entry_id, :label)

    def self.for_transaction(transaction)
      new(transaction).call
    end

    def initialize(transaction)
      @transaction = transaction
    end

    def call
      slips = []
      gift_card_count = 0
      store_credit_count = 0

      transaction.pos_transaction_lines.select(&:gift_card_sale_line?).each do |line|
        entry = issue_entry_for(line)
        next if entry.blank?

        gift_card_count += 1
        slips << SlipRef.new(
          ledger_entry_id: entry.id,
          label: gift_card_count == 1 ? "Print Gift Card" : "Print Gift Card #{gift_card_count}"
        )
      end

      transaction.pos_tenders.settlement_rows.each do |tender|
        next unless tender.stored_value_tender?
        next unless StoredValueTenderSupport.issue_tender?(transaction:, tender:)

        entry = issue_entry_for(tender)
        next if entry.blank?

        store_credit_count += 1
        slips << SlipRef.new(
          ledger_entry_id: entry.id,
          label: store_credit_count == 1 ? "Print Store Credit" : "Print Store Credit #{store_credit_count}"
        )
      end

      slips
    end

    private

    attr_reader :transaction

    def issue_entry_for(source)
      StoredValueLedgerEntry.find_by(source: source, entry_type: "issue")
    end
  end
end
