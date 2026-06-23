# frozen_string_literal: true

module Pos
  class GenerateStoredValueIdentifier
    Error = Class.new(StandardError)
    Generated = Data.define(:identifier, :display_value, :pos_tender_id)

    def self.call!(tender:, actor:, store:)
      new(tender:, actor:, store:).call!
    end

    def initialize(tender:, actor:, store:)
      @tender = tender
      @actor = actor
      @store = store
    end

    def call!
      raise Error, "Identifier generation is not requested." unless tender.generate_stored_value_identifier?
      raise Error, "Tender already has an identifier." if tender.stored_value_identifier_id.present?
      raise Error, "Stored value account is required." if tender.stored_value_account.blank?
      raise Error, "Identifiers can only be generated for refund credit issuance." unless tender.issue_tender?

      authorize!

      identifier = StoredValue::CreateIdentifier.call(
        account: tender.stored_value_account,
        actor: actor,
        identifier_type: "generated"
      )
      tender.update!(stored_value_identifier: identifier)

      Generated.new(
        identifier: identifier,
        display_value: formatted_value(identifier),
        pos_tender_id: tender.id
      )
    end

    private

    attr_reader :tender, :actor, :store

    def authorize!
      return if Authorization.allowed?(user: actor, permission_key: "stored_value.identifiers.create", store: store)
      return if TenderTypePolicy.refund_store_credit_permitted?(actor:, store: store)

      raise Error, "You are not authorized to generate stored value identifiers at POS."
    end

    def formatted_value(identifier)
      StoredValue::IdentifierCodec.format_display(
        StoredValue::IdentifierVault.decrypt(identifier.encrypted_value)
      )
    end
  end
end
