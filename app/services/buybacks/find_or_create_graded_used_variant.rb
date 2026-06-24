# frozen_string_literal: true

module Buybacks
  class FindOrCreateGradedUsedVariant
    class Error < StandardError; end

    def self.call!(product:, condition:, sub_department:, resale_price_cents:, session:, actor:)
      new(product:, condition:, sub_department:, resale_price_cents:, session:, actor:).call!
    end

    def initialize(product:, condition:, sub_department:, resale_price_cents:, session:, actor:)
      @product = product
      @condition = condition
      @sub_department = sub_department
      @resale_price_cents = resale_price_cents
      @session = session
      @actor = actor
    end

    def call!
      validate_inputs!

      existing = product.product_variants.active_records.find_by(condition: condition, sub_department: sub_department)
      if existing.present?
        Eligibility.ensure_variant_eligible!(variant: existing, condition: condition)
        if resale_price_cents.present? &&
            VariantPricePolicy.updatable_from_buyback?(variant: existing, store: session.store)
          existing.update!(selling_price_cents: resale_price_cents.to_i)
        end
        return existing
      end

      variant = ProductVariant.new(
        product: product,
        condition: condition,
        sub_department: sub_department,
        inventory_behavior: "standard_physical",
        selling_price_cents: resale_price_cents.to_i,
        source: "buyback_intake",
        needs_review: true,
        created_from_buyback_session: session,
        active: true
      )
      variant.name = ProductNameRenderer.variant_name(variant)
      variant.sku = SkuGenerator.variant_sku(variant)
      variant.save!

      AuditEvents.record!(
        actor: actor,
        event_name: "buyback.intake.product_variant_created",
        auditable: variant,
        source: session
      )

      variant
    end

    private

    attr_reader :product, :condition, :sub_department, :resale_price_cents, :session, :actor

    def validate_inputs!
      raise Error, "Condition is not buyback-eligible." unless condition.buyback_eligible?
      raise Error, "Subdepartment does not allow buyback." unless sub_department.buyback_allowed?
      raise Error, "New condition variants cannot be created via buyback." if condition.new_condition?
    end
  end
end
