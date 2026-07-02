# frozen_string_literal: true

module Sourcing
  class RunStatusRecalculator
    def self.call!(sourcing_run:)
      new(sourcing_run:).call!
    end

    def initialize(sourcing_run:)
      @sourcing_run = sourcing_run
    end

    def call!
      return sourcing_run if sourcing_run.terminal?

      new_status = resolve_status
      return sourcing_run if sourcing_run.status == new_status

      sourcing_run.update!(status: new_status)
      sourcing_run
    end

    private

    attr_reader :sourcing_run

    def resolve_status
      return "canceled" if sourcing_run.status == "canceled"

      if sourcing_run.sourcing_attempts.where(buyer_review_required: true).exists?
        return "needs_review"
      end

      if fully_resolved?
        "resolved"
      elsif any_terminal_attempt_outcome?
        "partially_resolved"
      else
        "open"
      end
    end

    def fully_resolved?
      sourcing_run.sourcing_attempts.in_flight.none? &&
        sourcing_run.sourcing_attempts.where(status: %w[pending submitted]).none? &&
        !sourcing_run.sourcing_attempts.where(buyer_review_required: true).exists?
    end

    def any_terminal_attempt_outcome?
      sourcing_run.sourcing_attempts.where(status: %w[confirmed partially_confirmed backordered failed cascaded canceled]).exists?
    end
  end
end
