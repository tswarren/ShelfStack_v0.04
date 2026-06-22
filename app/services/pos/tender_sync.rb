# frozen_string_literal: true

module Pos
  # Deprecated: delegates to Pos::SettlementSync. Remove after all callers migrate.
  class TenderSync
    Error = SettlementSync::Error
    Result = SettlementSync::Result
    TENDERED_REFERENCE_PREFIX = PosTender::TENDERED_REFERENCE_PREFIX

    def self.call!(transaction:, tender_inputs:, actor: nil)
      SettlementSync.call!(transaction:, tender_inputs:, actor:)
    end

    def self.tendered_cents_for(tender)
      SettlementSync.tendered_cents_for(tender)
    end

    def self.normalize_refund_amount_cents(transaction, amount_cents)
      SettlementInputParser.normalize_refund_amount_cents(transaction, amount_cents)
    end
  end
end
