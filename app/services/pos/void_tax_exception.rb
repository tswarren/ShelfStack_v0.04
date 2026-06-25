# frozen_string_literal: true

module Pos
  class VoidTaxException
    Error = Class.new(StandardError)

    def self.call!(record:, actor:, void_reason: nil)
      new(record:, actor:, void_reason:).call!
    end

    def initialize(record:, actor:, void_reason: nil)
      @record = record
      @actor = actor
      @void_reason = void_reason
    end

    def call!
      transaction = record.pos_transaction
      raise Error, "Transaction is not editable." unless transaction.editable?
      raise Error, "Tax exception record is already voided." if record.voided?

      transaction.transaction do
        record.update!(
          voided_at: Time.current,
          voided_by_user: actor,
          void_reason: void_reason
        )
        record_audit_event!
        RecalculateTransaction.call!(transaction, business_date: transaction.business_date || Date.current)
      end

      record.reload
    end

    private

    attr_reader :record, :actor, :void_reason

    def record_audit_event!
      event_name = case record
      when PosTaxExemption then "pos.tax_exemption.voided"
      when PosLineTaxOverride then "pos.line_tax_override.voided"
      else raise Error, "Unsupported tax exception record type."
      end
      AuditEvents.record!(
        actor: actor,
        event_name: event_name,
        auditable: record,
        source: record.pos_transaction,
        details: { void_reason: void_reason }.compact
      )
    end
  end
end
