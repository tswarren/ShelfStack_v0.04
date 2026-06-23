# frozen_string_literal: true

module Buybacks
  class UpdateLine
    def self.call!(line:, actor:, **attrs)
      new(line:, actor:, **attrs).call!
    end

    def initialize(line:, actor:, product_condition: nil, sub_department: nil, signed_copy: nil, notes: nil)
      @line = line
      @actor = actor
      @product_condition = product_condition
      @sub_department = sub_department
      @signed_copy = signed_copy
      @notes = notes
    end

    def call!
      raise ArgumentError, "Session is not editable." unless line.buyback_session.editable?

      updates = {}
      updates[:product_condition] = product_condition if product_condition.present?
      updates[:sub_department] = sub_department if sub_department.present?
      updates[:signed_copy] = signed_copy unless signed_copy.nil?
      updates[:notes] = notes if notes.present?
      line.assign_attributes(updates)

      if product_condition.present? || sub_department.present?
        pricing = PriceLine.call(line: line)
        line.assign_attributes(
          suggested_resale_price_cents: pricing.resale_price_cents,
          suggested_cash_offer_cents: pricing.cash_offer_cents,
          suggested_trade_credit_offer_cents: pricing.trade_credit_offer_cents,
          buyback_pricing_rule: pricing.pricing_rule,
          status: "priced"
        )
      end

      line.save!
      line
    end

    private

    attr_reader :line, :actor, :product_condition, :sub_department, :signed_copy, :notes
  end
end
