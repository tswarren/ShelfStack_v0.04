# frozen_string_literal: true

module CustomerRequests
  class ChangeLineType
    class ChangeError < StandardError; end

    def self.call!(request:, line:, request_type:, actor:)
      new(request:, line:, request_type:, actor:).call!
    end

    def initialize(request:, line:, request_type:, actor:)
      @request = request
      @line = line
      @request_type = request_type.to_s
      @actor = actor
    end

    def call!
      raise ChangeError, "Invalid request type" unless CustomerRequestLine::REQUEST_TYPES.include?(request_type)

      line.update!(request_type: request_type)
      request.refresh_status_from_lines!(actor: actor, source: line)

      AuditEvents.record!(
        actor: actor,
        event_name: "customer_request_line.type_changed",
        auditable: line,
        source: request,
        details: { "request_type" => request_type }
      )

      line
    end

    private

    attr_reader :request, :line, :request_type, :actor
  end
end
