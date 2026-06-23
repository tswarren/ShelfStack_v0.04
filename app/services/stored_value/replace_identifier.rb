# frozen_string_literal: true

module StoredValue
  class ReplaceIdentifier
    class Error < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(identifier:, actor:, identifier_type: "generated", raw_value: nil)
      @identifier = identifier
      @actor = actor
      @identifier_type = identifier_type
      @raw_value = raw_value
    end

    def call
      raise Error, "Identifier is already inactive" unless identifier.active?

      replacement = nil
      ActiveRecord::Base.transaction do
        replacement = CreateIdentifier.call(
          account: identifier.stored_value_account,
          actor: actor,
          identifier_type: identifier_type,
          raw_value: raw_value
        )

        identifier.update!(
          active: false,
          replaced_by_identifier: replacement
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "stored_value.identifier.replaced",
          auditable: replacement,
          source: identifier.stored_value_account,
          details: {
            "replaced_identifier_id" => identifier.id,
            "display_value_masked" => replacement.display_value_masked
          }
        )
      end

      replacement
    end

    private

    attr_reader :identifier, :actor, :identifier_type, :raw_value
  end
end
