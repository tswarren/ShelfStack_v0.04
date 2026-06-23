# frozen_string_literal: true

module StoredValue
  class RevealIdentifier
    class Error < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(identifier:, actor:, audit: true)
      @identifier = identifier
      @actor = actor
      @audit = audit
    end

    def call
      raise Error, "Full identifier is not available for this record" if identifier.encrypted_value.blank?

      value = IdentifierVault.decrypt(identifier.encrypted_value)
      raise Error, "Full identifier could not be recovered" if value.blank?

      record_audit! if audit

      value
    end

    private

    attr_reader :identifier, :actor, :audit

    def record_audit!
      AuditEvents.record!(
        actor: actor,
        event_name: "stored_value.identifier.revealed",
        auditable: identifier,
        source: identifier.stored_value_account,
        details: {
          "display_value_masked" => identifier.display_value_masked,
          "identifier_type" => identifier.identifier_type
        }
      )
    end
  end
end
