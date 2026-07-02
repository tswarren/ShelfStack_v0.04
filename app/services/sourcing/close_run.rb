# frozen_string_literal: true

module Sourcing
  class CloseRun
    class CloseRunError < StandardError; end

    def self.call!(sourcing_run:, actor:, close_reason: nil)
      new(sourcing_run:, actor:, close_reason:).call!
    end

    def initialize(sourcing_run:, actor:, close_reason: nil)
      @sourcing_run = sourcing_run
      @actor = actor
      @close_reason = close_reason
    end

    def call!
      raise CloseRunError, "Sourcing run is already terminal" if sourcing_run.terminal?

      unresolved = UnresolvedQuantity.for_demand_line(sourcing_run.demand_line)
      if unresolved.positive? && close_reason.blank?
        raise CloseRunError, "Close reason is required when unresolved demand quantity remains"
      end

      SourcingRun.transaction do
        locked_run = SourcingRun.lock.find(sourcing_run.id)
        raise CloseRunError, "Sourcing run is already terminal" if locked_run.terminal?

        now = Time.current
        locked_run.update!(
          status: "resolved",
          closed_by_user: actor,
          closed_at: now,
          close_reason: close_reason
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "sourcing_run.closed",
          auditable: locked_run,
          details: {
            "demand_number" => locked_run.demand_line.demand_number,
            "sourcing_run_id" => locked_run.id,
            "close_reason" => close_reason,
            "unresolved_for_sourcing" => unresolved
          }
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "sourcing_run.status_changed",
          auditable: locked_run,
          details: {
            "demand_number" => locked_run.demand_line.demand_number,
            "status" => "resolved"
          }
        )
      end

      sourcing_run.reload
    end

    private

    attr_reader :sourcing_run, :actor, :close_reason
  end
end
