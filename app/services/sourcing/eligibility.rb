# frozen_string_literal: true

module Sourcing
  module Eligibility
    Result = Data.define(:eligible, :reason)

    module_function

    def for_demand_line(demand_line)
      if demand_line.terminal?
        return Result.new(eligible: false, reason: "Demand line is terminal")
      end

      if demand_line.status == "captured"
        return Result.new(eligible: false, reason: "Captured demand must be matched before sourcing")
      end

      if demand_line.capture_intent == "used_wanted"
        return Result.new(eligible: false, reason: "Used-wanted demand is not vendor-sourced")
      end

      if demand_line.product_variant_id.blank?
        return Result.new(eligible: false, reason: "Demand line requires a product variant")
      end

      variant = demand_line.product_variant
      policy = ProductVariants::OperationalPolicy.for(variant)
      unless policy.vendor_sourcing_applicable?
        message = policy.vendor_sourcing_not_applicable_message || "Variant is not vendor-orderable"
        return Result.new(eligible: false, reason: message)
      end

      unresolved = UnresolvedQuantity.for_demand_line(demand_line)
      if unresolved <= 0
        return Result.new(eligible: false, reason: "No unresolved quantity for sourcing")
      end

      if SourcingRun.active_runs.exists?(demand_line_id: demand_line.id)
        return Result.new(eligible: false, reason: "Demand line already has an active sourcing run")
      end

      Result.new(eligible: true, reason: nil)
    end

    def eligible_demand_line?(demand_line)
      for_demand_line(demand_line).eligible
    end
  end
end
