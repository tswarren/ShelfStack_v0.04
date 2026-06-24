# frozen_string_literal: true

module Buybacks
  class Eligibility
    class Error < StandardError; end

    def self.ensure_line_eligible!(line:)
      new(line:).ensure_line_eligible!
    end

    def self.ensure_variant_eligible!(variant:, condition:)
      new(variant:, condition:).ensure_variant_eligible!
    end

    def initialize(line: nil, variant: nil, condition: nil)
      @line = line
      @variant = variant || line&.product_variant
      @condition = condition || line&.product_condition
      @sub_department = line&.sub_department || @variant&.sub_department
    end

    def ensure_line_eligible!
      raise Error, "Product variant is required." if variant.blank?
      raise Error, "Buyback condition is required." if condition.blank?
      raise Error, "Subdepartment is required." if sub_department.blank?

      ensure_variant_eligible!
    end

    def ensure_variant_eligible!
      raise Error, "Variant condition does not match selected buyback condition." if variant.condition_id != condition.id
      raise Error, "Condition is not buyback-eligible." unless condition.buyback_eligible?
      raise Error, "Subdepartment does not allow buyback." unless sub_department.buyback_allowed?
      raise Error, "Variant is not standard physical inventory." unless Inventory::Eligibility.eligible?(variant)
      raise Error, "Variant is not active." unless variant.active?
    end

    private

    attr_reader :line, :variant, :condition, :sub_department
  end
end
