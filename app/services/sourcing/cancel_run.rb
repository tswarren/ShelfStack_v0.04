# frozen_string_literal: true

module Sourcing
  class CancelRun
    class CancelRunError < StandardError; end

    def self.call!(sourcing_run:, actor:, cancel_reason:)
      new(sourcing_run:, actor:, cancel_reason:).call!
    end

    def initialize(sourcing_run:, actor:, cancel_reason:)
      @sourcing_run = sourcing_run
      @actor = actor
      @cancel_reason = cancel_reason
    end

    def call!
      raise CancelRunError, "Cancel reason is required" if cancel_reason.blank?
      raise CancelRunError, "Sourcing run is already terminal" if sourcing_run.terminal?

      SourcingRun.transaction do
        locked_run = SourcingRun.lock.find(sourcing_run.id)
        raise CancelRunError, "Sourcing run is already terminal" if locked_run.terminal?

        locked_run.sourcing_attempts.where(status: CancelAttempt::CANCELABLE_STATUSES).find_each do |attempt|
          CancelAttempt.call!(sourcing_attempt: attempt, actor: actor, cancel_reason: cancel_reason)
        end

        now = Time.current
        locked_run.update!(
          status: "canceled",
          canceled_by_user: actor,
          canceled_at: now,
          cancel_reason: cancel_reason
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "sourcing_run.canceled",
          auditable: locked_run,
          details: {
            "demand_number" => locked_run.demand_line.demand_number,
            "sourcing_run_id" => locked_run.id,
            "cancel_reason" => cancel_reason
          }
        )
      end

      sourcing_run.reload
    end

    private

    attr_reader :sourcing_run, :actor, :cancel_reason
  end
end
