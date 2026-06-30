# frozen_string_literal: true

module ProductVariants
  class LookupCodeService
    class LookupCodeError < StandardError; end

    GTIN_LENGTHS = [ 8, 12, 13, 14 ].freeze

    def self.add!(product_variant:, code:, code_type: "manual", store: nil, priority: 0, actor: nil, source: "manual")
      normalized = ProductVariantLookupCode.normalize_lookup_code(code)
      raise LookupCodeError, "Lookup code is required" if normalized.blank?
      validate_code!(normalized)

      ProductVariant.transaction do
        ensure_unique!(product_variant:, normalized:, store:, excluding_id: nil)
        lookup_code = product_variant.product_variant_lookup_codes.create!(
          store: store,
          code: code.to_s.strip.upcase,
          normalized_code: normalized,
          code_type: code_type,
          priority: priority,
          active: true
        )

        record_audit!(
          actor: actor,
          event_name: "variant_lookup_code.created",
          lookup_code: lookup_code,
          source: source
        )
        lookup_code
      end
    end

    def self.inactivate!(lookup_code:, actor: nil, source: "manual")
      ProductVariant.transaction do
        lookup_code.inactivate!
        record_audit!(
          actor: actor,
          event_name: "variant_lookup_code.inactivated",
          lookup_code: lookup_code,
          source: source,
          previous_value: lookup_code.normalized_code
        )
        lookup_code
      end
    end

    def self.resolve(normalized_code, store: nil)
      normalized = ProductVariantLookupCode.normalize_lookup_code(normalized_code)
      return if normalized.blank?

      scoped = ProductVariantLookupCode.active_records.where(normalized_code: normalized)
      if store.present?
        match = scoped.find_by(store_id: store.id)
        return match.product_variant if match.present?

        scoped.find_by(store_id: nil)&.product_variant
      else
        scoped.find_by(store_id: nil)&.product_variant
      end
    end

    def self.validate_code!(normalized)
      if normalized.length < ProductVariantLookupCode::MIN_CODE_LENGTH ||
          normalized.length > ProductVariantLookupCode::MAX_CODE_LENGTH
        raise LookupCodeError, "Lookup code must be #{ProductVariantLookupCode::MIN_CODE_LENGTH}-#{ProductVariantLookupCode::MAX_CODE_LENGTH} characters"
      end

      if normalized.match?(/\A[0-9]+\z/) && GTIN_LENGTHS.include?(normalized.length)
        raise LookupCodeError, "Lookup code cannot look like a GTIN-length numeric barcode"
      end
    end

    def self.ensure_unique!(product_variant:, normalized:, store:, excluding_id:)
      scope = ProductVariantLookupCode.active_records.where(normalized_code: normalized)
      scope = scope.where.not(id: excluding_id) if excluding_id.present?

      if store.present?
        conflict = scope.find_by(store_id: store.id)
        raise LookupCodeError, "Lookup code #{normalized} is already assigned" if conflict.present?
      else
        conflict = scope.find_by(store_id: nil)
        raise LookupCodeError, "Lookup code #{normalized} is already assigned globally" if conflict.present?
      end
    end
    private_class_method :ensure_unique!

    def self.record_audit!(actor:, event_name:, lookup_code:, source:, previous_value: nil)
      return if actor.blank?

      AuditEvents.record!(
        actor: actor,
        event_name: event_name,
        auditable: lookup_code,
        details: {
          "product_variant_id" => lookup_code.product_variant_id,
          "lookup_code_id" => lookup_code.id,
          "normalized_code" => lookup_code.normalized_code,
          "store_id" => lookup_code.store_id,
          "source" => source,
          "previous_value" => previous_value,
          "new_value" => lookup_code.normalized_code
        }.compact
      )
    end
    private_class_method :record_audit!
  end
end
