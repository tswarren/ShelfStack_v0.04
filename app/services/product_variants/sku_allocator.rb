# frozen_string_literal: true

module ProductVariants
  class SkuAllocator
    class AllocationError < StandardError; end

    SEGMENT = "211"
    PURPOSE = "variant_sku"

    def self.next_sku!
      InternalEanAllocator.allocate!(segment: SEGMENT, purpose: PURPOSE)
    end

    def self.assign!(product_variant:)
      raise AllocationError, "Variant already has a SKU" if product_variant.sku.present?

      product_variant.sku = next_sku!
    end

    def self.generate!(product_variant:, actor: nil, source: "system")
      assign!(product_variant: product_variant)
      product_variant.save!

      record_audit!(product_variant: product_variant, sku: product_variant.sku, actor: actor, source: source)
      product_variant.sku
    end

    def self.preview
      sequence = InternalEanSequence.find_by(segment: SEGMENT, purpose: PURPOSE)
      next_sequence = (sequence&.last_sequence || 0) + 1
      InternalEanAllocator.build_ean13(SEGMENT, next_sequence)
    end

    def self.record_audit!(product_variant:, sku:, actor:, source:)
      return if actor.blank?

      AuditEvents.record!(
        actor: actor,
        event_name: "variant_sku.generated",
        auditable: product_variant,
        details: {
          "product_id" => product_variant.product_id,
          "product_variant_id" => product_variant.id,
          "new_value" => sku,
          "segment" => SEGMENT,
          "source" => source
        }
      )
    end
    private_class_method :record_audit!
  end
end
