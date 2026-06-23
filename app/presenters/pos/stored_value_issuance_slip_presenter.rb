# frozen_string_literal: true

module Pos
  class StoredValueIssuanceSlipPresenter
    def initialize(transaction:, ledger_entry:, receipt: nil)
      @transaction = transaction
      @ledger_entry = ledger_entry
      @receipt = receipt || transaction.pos_receipt
    end

    attr_reader :transaction, :ledger_entry, :receipt

    def document_title
      gift_card? ? "GIFT CARD" : "STORE CREDIT"
    end

    def gift_card?
      case source
      when PosTransactionLine
        source.gift_card_sale_line?
      when PosTender
        source.tender_type == "gift_card"
      else
        ledger_entry.stored_value_account.account_type == "gift_card"
      end
    end

    def formatted_identifier
      identifier = resolved_identifier
      return if identifier.blank? || identifier.encrypted_value.blank?

      StoredValue::IdentifierCodec.format_display(
        StoredValue::IdentifierVault.decrypt(identifier.encrypted_value)
      )
    end

    def amount_cents
      ledger_entry.amount_delta_cents.to_i.abs
    end

    def balance_after_cents
      ledger_entry.balance_after_cents
    end

    def reload?
      balance_after_cents.to_i > amount_cents
    end

    def value_label
      reload? ? "Reload amount" : "Value"
    end

    private

    def source
      ledger_entry.source
    end

    def resolved_identifier
      case source
      when PosTransactionLine
        source.stored_value_identifier
      when PosTender
        source.stored_value_identifier
      else
        ledger_entry.stored_value_account.stored_value_identifiers.active_records.order(id: :desc).first
      end
    end
  end
end
