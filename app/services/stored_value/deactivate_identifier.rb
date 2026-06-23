# frozen_string_literal: true

module StoredValue
  class DeactivateIdentifier
    class Error < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(identifier:, actor:)
      @identifier = identifier
      @actor = actor
    end

    def call
      raise Error, "Identifier is already inactive" unless identifier.active?

      identifier.inactivate!

      AuditEvents.record!(
        actor: actor,
        event_name: "stored_value.identifier.deactivated",
        auditable: identifier,
        source: identifier.stored_value_account,
        details: {
          "display_value_masked" => identifier.display_value_masked
        }
      )

      identifier
    end

    private

    attr_reader :identifier, :actor
  end
end
