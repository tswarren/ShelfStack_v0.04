# frozen_string_literal: true

module CustomerRequests
  class RecordContact
    class RecordError < StandardError; end

    def self.call!(actor:, contact_method:, summary:, customer: nil, customer_request: nil,
                   customer_request_line_id: nil, direction: "outbound", status: "attempted",
                   occurred_at: Time.current)
      new(
        actor:, contact_method:, summary:, customer:, customer_request:,
        customer_request_line_id:, direction:, status:, occurred_at:
      ).call!
    end

    def initialize(actor:, contact_method:, summary:, customer: nil, customer_request: nil,
                   customer_request_line_id: nil, direction: "outbound", status: "attempted",
                   occurred_at: Time.current)
      @actor = actor
      @customer = customer
      @customer_request = customer_request
      @customer_request_line_id = customer_request_line_id
      @contact_method = contact_method
      @direction = direction
      @status = status
      @summary = summary
      @occurred_at = occurred_at
    end

    def call!
      raise RecordError, "Summary is required" if summary.blank?

      event = CustomerContactEvent.create!(
        customer: resolved_customer,
        customer_request: customer_request,
        customer_request_line_id: customer_request_line_id,
        contact_method: contact_method,
        direction: direction,
        status: status,
        summary: summary,
        recorded_by_user: actor,
        occurred_at: occurred_at
      )

      customer_request&.update!(last_contacted_at: occurred_at)

      AuditEvents.record!(
        actor: actor,
        event_name: "customer_contact_event.created",
        auditable: event,
        source: customer_request,
        details: { "customer_id" => resolved_customer&.id }
      )

      event
    end

    private

    attr_reader :actor, :customer, :customer_request, :customer_request_line_id,
                :contact_method, :direction, :status, :summary, :occurred_at

    def resolved_customer
      customer || customer_request&.customer
    end
  end
end
