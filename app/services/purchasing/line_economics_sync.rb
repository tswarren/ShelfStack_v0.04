# frozen_string_literal: true

module Purchasing
  module LineEconomicsSync
    module_function

    def apply!(line, recalculate_from_vendor: false, apply_defaults: :if_missing)
      apply_line_defaults!(line, apply_defaults)
      LineEconomicsCalculator.apply!(
        line,
        changed_field: changed_field_for(line),
        recalculate_from_vendor: recalculate_from_vendor
      )
      enforce_override_sources!(line)
      line
    end

    def apply_line_defaults!(line, apply_defaults)
      case apply_defaults
      when :always
        LinePriceDefaults.apply!(line)
      when :if_missing
        LinePriceDefaults.apply!(line) if line.unit_list_price_cents.nil? || line.supplier_discount_bps.nil?
      end
    end

    def changed_field_for(line)
      return "unit_cost_cents" if ActiveModel::Type::Boolean.new.cast(line.manual_cost_override)
      return "expected_retail_price_cents" if ActiveModel::Type::Boolean.new.cast(line.manual_price_override)

      nil
    end

    def enforce_override_sources!(line)
      line.cost_source = "manual" if ActiveModel::Type::Boolean.new.cast(line.manual_cost_override)
      line.price_source = "manual" if ActiveModel::Type::Boolean.new.cast(line.manual_price_override)
    end
  end
end
