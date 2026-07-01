# frozen_string_literal: true

module DemandLines
  class MatchVariant
    class MatchError < StandardError; end

    def self.call!(demand_line:, variant:, actor:)
      new(demand_line:, variant:, actor:).call!
    end

    def initialize(demand_line:, variant:, actor:)
      @demand_line = demand_line
      @variant = variant
      @actor = actor
    end

    def call!
      raise MatchError, "Demand line must be captured" unless demand_line.status == "captured"
      raise MatchError, "Variant is required" if variant.blank?
      raise MatchError, "Variant must be active" unless variant.active?

      DemandLine.transaction do
        demand_line.update!(
          status: "open",
          product_variant: variant,
          product: variant.product,
          matched_by_user: actor,
          matched_at: Time.current
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_line.matched",
          auditable: demand_line,
          details: {
            "product_variant_id" => variant.id,
            "demand_number" => demand_line.demand_number
          }
        )
      end

      demand_line
    end

    private

    attr_reader :demand_line, :variant, :actor
  end
end
