# frozen_string_literal: true

module Sourcing
  class CancelAttempt
    class CancelAttemptError < StandardError; end

    CANCELABLE_STATUSES = %w[pending submitted].freeze

    def self.call!(sourcing_attempt:, actor:, cancel_reason:)
      new(sourcing_attempt:, actor:, cancel_reason:).call!
    end

    def initialize(sourcing_attempt:, actor:, cancel_reason:)
      @sourcing_attempt = sourcing_attempt
      @actor = actor
      @cancel_reason = cancel_reason
    end

    def call!
      raise CancelAttemptError, "Cancel reason is required" if cancel_reason.blank?
      raise CancelAttemptError, "Attempt is not cancelable" unless CANCELABLE_STATUSES.include?(sourcing_attempt.status)

      SourcingAttempt.transaction do
        locked_attempt = SourcingAttempt.lock.find(sourcing_attempt.id)
        raise CancelAttemptError, "Attempt is not cancelable" unless CANCELABLE_STATUSES.include?(locked_attempt.status)

        now = Time.current
        locked_attempt.update!(
          status: "canceled",
          canceled_by_user: actor,
          canceled_at: now,
          cancel_reason: cancel_reason
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "sourcing_attempt.canceled",
          auditable: locked_attempt,
          details: {
            "demand_number" => locked_attempt.demand_line.demand_number,
            "sourcing_attempt_id" => locked_attempt.id,
            "cancel_reason" => cancel_reason
          }
        )

        RunStatusRecalculator.call!(sourcing_run: locked_attempt.sourcing_run.reload)
      end

      sourcing_attempt.reload
    end

    private

    attr_reader :sourcing_attempt, :actor, :cancel_reason
  end
end
