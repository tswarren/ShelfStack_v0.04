# frozen_string_literal: true

module Pos
  class TaxExceptionApplicationService
    Error = Class.new(StandardError)

    SCOPES = %w[transaction line].freeze

    def self.call!(transaction:, scope:, tax_exception_reason:, actor:, line: nil,
                  override_tax_category: nil, certificate_number: nil, note: nil)
      new(
        transaction:,
        scope:,
        line:,
        tax_exception_reason:,
        override_tax_category:,
        certificate_number:,
        note:,
        actor:
      ).call!
    end

    def initialize(transaction:, scope:, tax_exception_reason:, actor:, line: nil,
                   override_tax_category: nil, certificate_number: nil, note: nil)
      @transaction = transaction
      @scope = scope.to_s
      @line = line
      @tax_exception_reason = tax_exception_reason
      @override_tax_category = override_tax_category
      @certificate_number = certificate_number
      @note = note
      @actor = actor
    end

    def call!
      validate_editable!
      validate_scope!
      validate_reason!
      validate_note!
      validate_certificate!
      validate_line! if line_scope?

      record = nil
      transaction.transaction do
        void_prior_active_record!
        record = create_record!
        record_audit_event!(record)
        RecalculateTransaction.call!(transaction, business_date: transaction.business_date || Date.current)
      end

      record.reload
    end

    private

    attr_reader :transaction, :scope, :line, :tax_exception_reason, :override_tax_category,
                :certificate_number, :note, :actor

    def transaction_scope?
      scope == "transaction"
    end

    def line_scope?
      scope == "line"
    end

    def validate_editable!
      raise Error, "Transaction is not editable." unless transaction.editable?
    end

    def validate_scope!
      raise Error, "Invalid scope." unless SCOPES.include?(scope)
    end

    def validate_reason!
      raise Error, "Tax exception reason is not active." unless tax_exception_reason.active?

      if transaction_scope? && !tax_exception_reason.allows_exemption?
        raise Error, "Tax exception reason does not allow exemption."
      end

      if line_scope? && !tax_exception_reason.allows_rate_override?
        raise Error, "Tax exception reason does not allow rate override."
      end
    end

    def validate_note!
      return unless tax_exception_reason.requires_note?
      raise Error, "A note is required for this tax exception reason." if note.blank?
    end

    def validate_certificate!
      return unless transaction_scope?
      return unless tax_exception_reason.requires_certificate?
      raise Error, "A certificate/reference is required for this tax exception reason." if certificate_number.blank?
    end

    def validate_line!
      raise Error, "Line is required for line-scope tax exceptions." if line.blank?
      raise Error, "Line does not belong to this transaction." if line.pos_transaction_id != transaction.id
      raise Error, "Gift card sale lines cannot receive tax overrides." if line.gift_card_sale_line?
      raise Error, "Sourced return lines cannot receive tax overrides." if line.return_line? && line.source_transaction_line_id.present?
      raise Error, "Open-ring lines require a tax category before override." if line.open_ring_line? && line.tax_category_id.blank?
      raise Error, "Override tax category is required." if override_tax_category.blank?
      raise Error, "Only positive sale lines can receive tax overrides." unless line.quantity.positive?
    end

    def void_prior_active_record!
      if transaction_scope?
        transaction.pos_tax_exemptions.active_records.find_each do |exemption|
          exemption.update!(
            voided_at: Time.current,
            voided_by_user: actor,
            void_reason: "Replaced by new exemption"
          )
        end
      else
        line.pos_line_tax_overrides.active_records.find_each do |override|
          override.update!(
            voided_at: Time.current,
            voided_by_user: actor,
            void_reason: "Replaced by new override"
          )
        end
      end
    end

    def create_record!
      if transaction_scope?
        PosTaxExemption.create!(
          pos_transaction: transaction,
          tax_exception_reason: tax_exception_reason,
          certificate_number: certificate_number,
          note: note,
          exempted_by_user: actor,
          exempted_at: Time.current
        )
      else
        rate = TaxRateLookup.call(
          store: transaction.store,
          tax_category: override_tax_category,
          date: transaction.business_date || Date.current
        )
        PosLineTaxOverride.create!(
          pos_transaction: transaction,
          pos_transaction_line: line,
          tax_exception_reason: tax_exception_reason,
          override_tax_category: override_tax_category,
          override_store_tax_rate: rate,
          override_tax_rate_bps: rate.tax_rate_bps,
          override_tax_identifier_snapshot: rate.tax_identifier,
          override_store_tax_rate_short_name_snapshot: rate.short_name,
          note: note,
          overridden_by_user: actor,
          overridden_at: Time.current
        )
      end
    end

    def record_audit_event!(record)
      event_name = record.is_a?(PosTaxExemption) ? "pos.tax_exemption.applied" : "pos.line_tax_override.applied"
      AuditEvents.record!(
        actor: actor,
        event_name: event_name,
        auditable: record,
        source: transaction,
        details: {
          tax_exception_reason_key: tax_exception_reason.reason_key,
          certificate_number: certificate_number,
          note: note,
          pos_transaction_line_id: line&.id,
          override_tax_category_id: override_tax_category&.id
        }.compact
      )
    end
  end
end
