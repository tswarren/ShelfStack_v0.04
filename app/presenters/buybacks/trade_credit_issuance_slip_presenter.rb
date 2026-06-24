# frozen_string_literal: true

module Buybacks
  class TradeCreditIssuanceSlipPresenter
    def initialize(session:, ledger_entry:, actor:)
      @session = session
      @ledger_entry = ledger_entry
      @actor = actor
    end

    attr_reader :session, :ledger_entry, :actor

    def document_title
      "TRADE CREDIT"
    end

    def formatted_identifier
      identifier = ledger_entry.stored_value_account.stored_value_identifiers.active_records.order(id: :desc).first
      return if identifier.blank?

      value = StoredValue::RevealIdentifier.call(identifier: identifier, actor: actor, audit: false)
      StoredValue::IdentifierCodec.format_display(value)
    end

    def amount_cents
      ledger_entry.amount_delta_cents.to_i.abs
    end

    def balance_after_cents
      ledger_entry.balance_after_cents
    end

    def buyback_number
      session.buyback_number
    end

    def seller_name
      session.seller_display_name_snapshot || session.customer.display_name
    end
  end
end
