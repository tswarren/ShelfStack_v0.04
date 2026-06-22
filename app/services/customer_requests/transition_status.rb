# frozen_string_literal: true

module CustomerRequests
  class TransitionStatus
    class TransitionError < StandardError; end

    MANUAL_STATUSES = %w[cancelled unfillable completed].freeze

    def self.call!(request:, status:, actor:, reason: nil)
      new(request:, status:, actor:, reason:).call!
    end

    def initialize(request:, status:, actor:, reason: nil)
      @request = request
      @status = status
      @actor = actor
      @reason = reason
    end

    def call!
      raise TransitionError, "Invalid status" unless CustomerRequest::STATUSES.include?(status)
      raise TransitionError, "Use Cancel or MarkUnfillable for terminal transitions" unless MANUAL_STATUSES.include?(status)

      prior = request.status
      attrs = { status: status }
      case status
      when "cancelled"
        attrs[:cancelled_at] = Time.current
        attrs[:cancellation_reason] = reason
      when "unfillable"
        attrs[:unfillable_reason] = reason
      when "completed"
        attrs[:completed_at] = Time.current
      end

      CustomerRequest.transaction do
        request.update!(attrs)
        AuditEvents.record!(
          actor: actor,
          event_name: "customer_request.status_changed",
          auditable: request,
          details: { "prior_status" => prior, "new_status" => status, "reason" => reason }
        )
      end
      request
    end

    private

    attr_reader :request, :status, :actor, :reason
  end
end
