# frozen_string_literal: true

module CustomerRequests
  class MarkAwaitingResponse
    def self.call!(request:, line:, actor:)
      new(request:, line:, actor:).call!
    end

    def initialize(request:, line:, actor:)
      @request = request
      @line = line
      @actor = actor
    end

    def call!
      line.update!(status: "awaiting_customer_response")
      request.refresh_status_from_lines!(actor: actor, source: line)

      AuditEvents.record!(
        actor: actor,
        event_name: "customer_request_line.awaiting_response",
        auditable: line,
        source: request
      )

      line
    end

    private

    attr_reader :request, :line, :actor
  end
end
