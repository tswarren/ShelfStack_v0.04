# frozen_string_literal: true

module Buybacks
  class SelectVariant
    class Error < StandardError; end

    def self.call!(line:, session:, variant:, actor:)
      new(line:, session:, variant:, actor:).call!
    end

    def initialize(line:, session:, variant:, actor:)
      @line = line
      @session = session
      @variant = variant
      @actor = actor
    end

    def call!
      raise Error, "Session is not editable." unless session.editable?
      raise Error, "Line does not belong to session." unless line.buyback_session_id == session.id

      product = variant.product

      line.update!(
        product_variant: variant,
        product: product,
        product_condition: variant.condition,
        sub_department: variant.sub_department,
        title_snapshot: product.display_title,
        variant_sku_snapshot: variant.sku,
        condition_snapshot: variant.condition&.name,
        list_price_cents: product.list_price_cents,
        status: "resolved"
      )
      PricingFieldSync.refresh!(line: line.reload)

      AuditEvents.record!(
        actor: actor,
        event_name: "buyback.line.variant_selected",
        auditable: line,
        source: session,
        details: { "product_variant_id" => variant.id }
      )

      line
    end

    private

    attr_reader :line, :session, :variant, :actor
  end
end
