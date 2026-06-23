# frozen_string_literal: true

module Pos
  class GenerateStoredValueIdentifier
    Error = Class.new(StandardError)
    Generated = Data.define(:identifier, :display_value, :pos_tender_id, :pos_transaction_line_id)

    def self.call!(tender:, actor:, store:)
      new(tender:, actor:, store:).call!
    end

    def self.call_for_line!(line:, actor:, store:)
      new(line:, actor:, store:).call!
    end

    def initialize(tender: nil, line: nil, actor:, store:)
      @tender = tender
      @line = line
      @actor = actor
      @store = store
    end

    def call!
      raise Error, "Identifier generation is not requested." unless generate_requested?
      raise Error, "Target already has an identifier." if identifier_id.present?
      raise Error, "Stored value account is required." if account.blank?
      raise Error, "Identifier generation is not allowed for this target." unless generation_allowed?

      authorize!

      identifier = StoredValue::CreateIdentifier.call(
        account: account,
        actor: actor,
        identifier_type: "generated"
      )
      attrs = { stored_value_identifier: identifier }
      attrs[:generate_stored_value_identifier] = false if line.present?
      target.update!(attrs)

      Generated.new(
        identifier: identifier,
        display_value: formatted_value(identifier),
        pos_tender_id: tender&.id,
        pos_transaction_line_id: line&.id
      )
    end

    private

    attr_reader :tender, :line, :actor, :store

    def target
      tender || line
    end

    def generate_requested?
      if tender.present?
        tender.generate_stored_value_identifier?
      else
        line.generate_stored_value_identifier?
      end
    end

    def identifier_id
      target.stored_value_identifier_id
    end

    def account
      target.stored_value_account
    end

    def generation_allowed?
      if tender.present?
        tender.issue_tender?
      else
        line.gift_card_sale_line?
      end
    end

    def authorize!
      if line.present?
        return if GiftCardSalePolicy.issue_permitted?(actor:, store: store)
      elsif Authorization.allowed?(user: actor, permission_key: "stored_value.identifiers.create", store: store)
        return
      elsif TenderTypePolicy.refund_store_credit_permitted?(actor:, store: store)
        return
      end

      raise Error, "You are not authorized to generate stored value identifiers at POS."
    end

    def formatted_value(identifier)
      StoredValue::IdentifierCodec.format_display(
        StoredValue::IdentifierVault.decrypt(identifier.encrypted_value)
      )
    end
  end
end
