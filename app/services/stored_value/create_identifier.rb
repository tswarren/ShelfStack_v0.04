# frozen_string_literal: true

module StoredValue
  class CreateIdentifier
    class Error < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(account:, actor:, identifier_type:, raw_value: nil)
      @account = account
      @actor = actor
      @identifier_type = identifier_type
      @raw_value = raw_value
    end

    def call
      raise Error, "Account is not active" unless account.active?

      attrs = case identifier_type
      when "generated"
                generated_attrs
      when "manual", "legacy_import"
                manual_attrs
      else
                raise Error, "Unsupported identifier type"
      end

      identifier = StoredValueIdentifier.create!(
        stored_value_account: account,
        identifier_type: identifier_type,
        **attrs
      )

      AuditEvents.record!(
        actor: actor,
        event_name: "stored_value.identifier.created",
        auditable: identifier,
        source: account,
        details: {
          "identifier_type" => identifier_type,
          "display_value_masked" => identifier.display_value_masked
        }
      )

      identifier
    end

    private

    attr_reader :account, :actor, :identifier_type, :raw_value

    def generated_attrs
      generated = IdentifierCodec.generate
      {
        lookup_digest: generated[:lookup_digest],
        display_value_masked: generated[:display_value_masked],
        encrypted_value: IdentifierVault.encrypt!(generated[:normalized_value])
      }
    end

    def manual_attrs
      raise Error, "Identifier value is required" if raw_value.blank?

      normalized = IdentifierCodec.validate!(raw_value)
      digest = IdentifierCodec.digest(normalized)
      raise Error, "Identifier is already in use" if StoredValueIdentifier.active_records.exists?(lookup_digest: digest)

      {
        lookup_digest: digest,
        display_value_masked: IdentifierCodec.mask(normalized),
        encrypted_value: IdentifierVault.encrypt!(normalized)
      }
    end
  end
end
