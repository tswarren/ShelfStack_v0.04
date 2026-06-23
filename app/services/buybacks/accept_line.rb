# frozen_string_literal: true

module Buybacks
  class AcceptLine
    class Error < StandardError; end

    def self.call!(line:, session:, actor:, outcome:, product_variant:, product_condition:, sub_department:, resale_price_cents: nil, offer_cents: nil)
      new(line:, session:, actor:, outcome:, product_variant:, product_condition:, sub_department:,
          resale_price_cents:, offer_cents:).call!
    end

    def initialize(line:, session:, actor:, outcome:, product_variant:, product_condition:, sub_department:,
                   resale_price_cents: nil, offer_cents: nil)
      @line = line
      @session = session
      @actor = actor
      @outcome = outcome
      @product_variant = product_variant
      @product_condition = product_condition
      @sub_department = sub_department
      @resale_price_cents = resale_price_cents
      @offer_cents = offer_cents
    end

    def call!
      raise Error, "Session is not editable." unless session.editable?

      line.assign_attributes(
        product_variant: product_variant,
        product: product_variant.product,
        catalog_item: product_variant.product.catalog_item,
        product_condition: product_condition,
        sub_department: sub_department,
        outcome: outcome,
        status: "accepted",
        accepted_resale_price_cents: resale_price_cents || line.accepted_resale_price_cents,
        accepted_offer_cents: offer_cents || line.accepted_offer_cents,
        variant_sku_snapshot: product_variant.sku,
        condition_snapshot: product_condition.name
      )

      Eligibility.ensure_line_eligible!(line: line)
      line.save!

      if line.accepted_resale_price_cents.present?
        product_variant.update!(selling_price_cents: line.accepted_resale_price_cents)
      end

      AuditEvents.record!(actor: actor, event_name: "buyback.line.accepted", auditable: line, source: session)
      line
    end

    private

    attr_reader :line, :session, :actor, :outcome, :product_variant, :product_condition,
                :sub_department, :resale_price_cents, :offer_cents
  end
end
