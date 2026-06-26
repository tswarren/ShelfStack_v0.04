# frozen_string_literal: true

module Purchasing
  module LineEconomicsSync
    module_function

    def apply!(line, recalculate_from_vendor: false)
      LinePriceDefaults.apply!(line) if line.unit_list_price_cents.nil? || line.supplier_discount_bps.nil?
      LineEconomicsCalculator.apply!(
        line,
        changed_field: changed_field_for(line),
        recalculate_from_vendor: recalculate_from_vendor
      )
      line
    end

    def changed_field_for(line)
      return "unit_cost_cents" if ActiveModel::Type::Boolean.new.cast(line.manual_cost_override)
      return "expected_retail_price_cents" if ActiveModel::Type::Boolean.new.cast(line.manual_price_override)

      nil
    end
  end
end
