# frozen_string_literal: true

module CustomerRequests
  class HeaderStatusResolver
    TERMINAL_STATUSES = %w[completed cancelled unfillable].freeze

    def self.call!(request, actor: nil, source: nil)
      new(request, actor: actor, source: source).call!
    end

    def initialize(request, actor: nil, source: nil)
      @request = request
      @actor = actor
      @source = source
    end

    def call!
      return request if TERMINAL_STATUSES.include?(request.status)

      lines = request.customer_request_lines.reload
      return request if lines.empty?

      new_status = derive_status(lines)
      return request if new_status == request.status

      prior_status = request.status
      request.update!(status: new_status)
      record_status_change!(prior_status:, new_status:)
      request
    end

    private

    attr_reader :request, :actor, :source

    def record_status_change!(prior_status:, new_status:)
      AuditEvents.record!(
        actor: resolved_actor,
        event_name: "customer_request.status_changed",
        auditable: request,
        source: source,
        details: {
          "prior_status" => prior_status,
          "new_status" => new_status,
          "derived_from" => "lines"
        }
      )
    end

    def resolved_actor
      actor || Current.user || request.created_by_user
    end

    def derive_status(lines)
      active = lines.reject { |line| %w[cancelled unfillable].include?(line.status) }
      return "cancelled" if active.empty? && lines.all? { |l| l.status == "cancelled" }
      if active.empty? && lines.any? { |l| l.status == "unfillable" }
        return "partially_filled" if lines.any? { |l| l.status == "cancelled" }

        return "unfillable"
      end

      return "completed" if active.all? { |l| l.status == "completed" }
      return "ready_for_pickup" if active.all? { |l| l.status == "ready_for_pickup" }
      return "partially_filled" if active.any? { |l| l.status == "partially_filled" }
      return "partially_filled" if active.any? { |l| l.status == "completed" } &&
                                   active.any? { |l| l.status != "completed" }
      return "partially_filled" if active.any? { |l| l.status == "ready_for_pickup" } &&
                                   active.any? { |l| l.status != "ready_for_pickup" }
      return "ordered" if active.any? { |l| l.status == "ordered" }
      return "approved_to_order" if active.any? { |l| l.status == "approved" }
      return "awaiting_customer_response" if active.any? { |l| l.status == "awaiting_customer_response" }
      return "researching" if active.any? { |l| %w[researching matched].include?(l.status) }

      "new"
    end
  end
end
