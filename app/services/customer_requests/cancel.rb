# frozen_string_literal: true

module CustomerRequests
  class Cancel
    class CancelError < StandardError; end

    def self.call!(request:, actor:, reason:)
      new(request:, actor:, reason:).call!
    end

    def initialize(request:, actor:, reason:)
      @request = request
      @actor = actor
      @reason = reason
    end

    def call!
      raise CancelError, "Cancellation reason is required" if reason.blank?

      CustomerRequest.transaction do
        request.customer_request_lines.open_lines.find_each do |line|
          line.update!(status: "cancelled", cancelled_quantity: line.remaining_quantity)
        end
        request.update!(status: "cancelled", cancelled_at: Time.current, cancellation_reason: reason)

        AuditEvents.record!(
          actor: actor,
          event_name: "customer_request.cancelled",
          auditable: request,
          details: { "reason" => reason }
        )
      end
      request
    end

    private

    attr_reader :request, :actor, :reason
  end
end
