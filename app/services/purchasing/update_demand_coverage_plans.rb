# frozen_string_literal: true

module Purchasing
  class UpdateDemandCoveragePlans
    class UpdateError < StandardError; end

    def self.call!(purchase_order:, actor:, line_plans:)
      new(purchase_order:, actor:, line_plans:).call!
    end

    def initialize(purchase_order:, actor:, line_plans:)
      @purchase_order = purchase_order
      @actor = actor
      @line_plans = Array(line_plans)
    end

    def call!
      raise UpdateError, "Purchase order must be draft" unless purchase_order.draft?

      ReleaseDemandCoveragePlan.call!(
        purchase_order: purchase_order,
        actor: actor,
        reason: "Replaced by updated demand coverage"
      ) if purchase_order.purchase_order_line_demand_plans.active_plans.exists?

      CreateDemandCoveragePlans.call!(purchase_order: purchase_order, actor: actor, line_plans: line_plans)
    end

    private

    attr_reader :purchase_order, :actor, :line_plans
  end
end
