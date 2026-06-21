# frozen_string_literal: true

module CustomerRequests
  class AddLine
    class AddLineError < StandardError; end

    def self.call(request:, line_attributes:, added_by_user:)
      new(request:, line_attributes:, added_by_user:).call
    end

    def initialize(request:, line_attributes:, added_by_user:)
      @request = request
      @line_attributes = line_attributes
      @added_by_user = added_by_user
    end

    def call
      line = nil
      CustomerRequest.transaction do
        next_number = (request.customer_request_lines.maximum(:line_number) || 0) + 1
        line = request.customer_request_lines.create!(
          line_attributes.merge(line_number: next_number, status: "new")
        )
        request.refresh_status_from_lines!

        AuditEvents.record!(
          actor: added_by_user,
          event_name: "customer_request_line.created",
          auditable: line,
          details: { "request_number" => request.request_number, "line_number" => line.line_number }
        )
      end
      line
    end

    private

    attr_reader :request, :line_attributes, :added_by_user
  end
end
