# frozen_string_literal: true

module CustomerRequests
  class MatchVariant
    class MatchError < StandardError; end

    def self.call!(line:, variant:, actor:)
      new(line:, variant:, actor:).call!
    end

    def initialize(line:, variant:, actor:)
      @line = line
      @variant = variant
      @actor = actor
    end

    def call!
      raise MatchError, "Variant is required" if variant.blank?
      raise MatchError, "Line is already matched" if line.matched?
      raise MatchError, "Line is no longer open" if line.status.in?(%w[completed cancelled unfillable])
      raise MatchError, "Variant must be active" unless variant.active?

      CustomerRequest.transaction do
        line.update!(
          product_variant: variant,
          product: variant.product,
          catalog_item: variant.product.catalog_item,
          status: "matched"
        )
        line.customer_request.refresh_status_from_lines!

        AuditEvents.record!(
          actor: actor,
          event_name: "customer_request_line.matched_variant",
          auditable: line,
          details: {
            "product_variant_id" => variant.id,
            "sku" => variant.sku
          }
        )
      end
      line
    end

    private

    attr_reader :line, :variant, :actor
  end
end
