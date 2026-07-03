# frozen_string_literal: true

module Purchasing
  class ReleaseDemandCoveragePlan
    class ReleaseError < StandardError; end

    def self.call!(purchase_order:, actor:, reason:, demand_line: nil)
      new(purchase_order:, actor:, reason:, demand_line:).call!
    end

    def initialize(purchase_order:, actor:, reason:, demand_line: nil)
      @purchase_order = purchase_order
      @actor = actor
      @reason = reason
      @demand_line = demand_line
    end

    def call!
      raise ReleaseError, "Release reason is required" if reason.blank?

      scope = purchase_order.purchase_order_line_demand_plans.active_plans
      scope = scope.where(demand_line: demand_line) if demand_line.present?

      now = Time.current
      PurchaseOrder.transaction do
        scope.find_each do |plan|
          if plan.coverage_kind == "customer_fulfillment" && reason.blank?
            raise ReleaseError, "Customer coverage release requires a reason"
          end

          plan.update!(
            status: "released",
            released_at: now,
            released_by_user: actor,
            release_reason: reason
          )
          AuditEvents.record!(
            actor: actor,
            event_name: "purchase_order_line_demand_plan.released",
            auditable: plan,
            details: { "reason" => reason }
          )
        end
      end
    end

    private

    attr_reader :purchase_order, :actor, :reason, :demand_line
  end
end
