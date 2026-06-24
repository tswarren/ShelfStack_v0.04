# frozen_string_literal: true

module Buybacks
  class UpdateProposalLine
    class Error < StandardError; end

    def self.call!(line:, session:, actor:, product_condition: nil, sub_department: nil,
                   base_price_cents: nil, base_price_source: nil,
                   proposed_resale_price_cents: nil, proposed_cash_offer_cents: nil,
                   proposed_trade_credit_offer_cents: nil,
                   resale_override_reason: nil, cash_override_reason: nil, trade_credit_override_reason: nil,
                   signed_copy: nil, notes: nil)
      new(
        line:, session:, actor:, product_condition:, sub_department:,
        base_price_cents:, base_price_source:,
        proposed_resale_price_cents:, proposed_cash_offer_cents:, proposed_trade_credit_offer_cents:,
        resale_override_reason:, cash_override_reason:, trade_credit_override_reason:,
        signed_copy:, notes:
      ).call!
    end

    def initialize(line:, session:, actor:, product_condition: nil, sub_department: nil,
                   base_price_cents: nil, base_price_source: nil,
                   proposed_resale_price_cents: nil, proposed_cash_offer_cents: nil,
                   proposed_trade_credit_offer_cents: nil,
                   resale_override_reason: nil, cash_override_reason: nil, trade_credit_override_reason: nil,
                   signed_copy: nil, notes: nil)
      @line = line
      @session = session
      @actor = actor
      @product_condition = product_condition
      @sub_department = sub_department
      @base_price_cents = base_price_cents
      @base_price_source = base_price_source
      @proposed_resale_price_cents = proposed_resale_price_cents
      @proposed_cash_offer_cents = proposed_cash_offer_cents
      @proposed_trade_credit_offer_cents = proposed_trade_credit_offer_cents
      @resale_override_reason = resale_override_reason
      @cash_override_reason = cash_override_reason
      @trade_credit_override_reason = trade_credit_override_reason
      @signed_copy = signed_copy
      @notes = notes
    end

    def call!
      raise Error, "Session is not editable." unless session.editable?
      raise Error, "Line does not belong to session." unless line.buyback_session_id == session.id

      line.product_condition = product_condition if product_condition.present?
      line.sub_department = sub_department if sub_department.present?
      line.base_price_cents = base_price_cents if base_price_cents.present?
      line.base_price_source = base_price_source if base_price_source.present?
      line.signed_copy = signed_copy unless signed_copy.nil?
      line.notes = notes if notes.present?

      raise Error, "Condition is required for pricing." if line.product_condition.blank?
      raise Error, "Subdepartment is required for pricing." if line.sub_department.blank?

      pricing = PriceLine.call(line: line)
      PricingFieldSync.apply_suggested_values!(line, pricing)

      apply_explicit_proposed_values!
      validate_proposed_resale_price!
      ensure_product_and_variant!
      clear_stale_decision!

      Eligibility.ensure_line_eligible!(line: line)
      line.status = "priced"
      line.save!

      AuditEvents.record!(actor: actor, event_name: "buyback.line.proposal_updated", auditable: line, source: session)
      line
    end

    private

    attr_reader :line, :session, :actor, :product_condition, :sub_department,
                :base_price_cents, :base_price_source,
                :proposed_resale_price_cents, :proposed_cash_offer_cents, :proposed_trade_credit_offer_cents,
                :resale_override_reason, :cash_override_reason, :trade_credit_override_reason,
                :signed_copy, :notes

    def apply_explicit_proposed_values!
      if proposed_resale_price_cents.present?
        apply_value_override!(
          value: proposed_resale_price_cents.to_i,
          suggested: line.suggested_resale_price_cents.to_i,
          reason: resale_override_reason,
          flag: :resale_price_overridden,
          reason_field: :resale_price_override_reason
        )
        line.proposed_resale_price_cents = proposed_resale_price_cents.to_i
      end

      if proposed_cash_offer_cents.present?
        apply_value_override!(
          value: proposed_cash_offer_cents.to_i,
          suggested: line.suggested_cash_offer_cents.to_i,
          reason: cash_override_reason,
          flag: :cash_offer_overridden,
          reason_field: :cash_offer_override_reason
        )
        line.proposed_cash_offer_cents = proposed_cash_offer_cents.to_i
      end

      if proposed_trade_credit_offer_cents.present?
        apply_value_override!(
          value: proposed_trade_credit_offer_cents.to_i,
          suggested: line.suggested_trade_credit_offer_cents.to_i,
          reason: trade_credit_override_reason,
          flag: :trade_credit_offer_overridden,
          reason_field: :trade_credit_offer_override_reason
        )
        line.proposed_trade_credit_offer_cents = proposed_trade_credit_offer_cents.to_i
      end
    end

    def apply_value_override!(value:, suggested:, reason:, flag:, reason_field:)
      return if value == suggested

      raise Error, "Override reason is required when proposed values differ from suggested." if reason.blank?
      raise Error, "Price override permission is required." unless override_allowed?

      line.public_send("#{flag}=", true)
      line.public_send("#{reason_field}=", reason)
    end

    def override_allowed?
      Authorization.allowed?(user: actor, permission_key: "buybacks.price_override", store: session.store)
    end

    def validate_proposed_resale_price!
      price = line.proposed_resale_price_cents.to_i
      return if price.positive?
      return if line.resale_price_overridden? && line.resale_price_override_reason.present?

      raise Error, "Proposed resale price must be greater than zero."
    end

    def clear_stale_decision!
      return unless line.outcome.present? || line.status == "decided"

      line.outcome = nil
      line.customer_decision_at = nil
    end

    def ensure_product_and_variant!
      product = line.product || line.catalog_item&.products&.active_records&.first
      raise Error, "Product linkage is required before pricing." if product.blank?

      line.product = product
      line.catalog_item ||= product.catalog_item

      variant = FindOrCreateGradedUsedVariant.call!(
        product: product,
        condition: line.product_condition,
        sub_department: line.sub_department,
        resale_price_cents: line.proposed_resale_price_cents,
        session: session,
        actor: actor
      )

      line.product_variant = variant
      line.variant_sku_snapshot = variant.sku
      line.condition_snapshot = line.product_condition.name
    end
  end
end
