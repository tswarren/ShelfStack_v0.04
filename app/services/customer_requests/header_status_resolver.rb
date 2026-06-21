# frozen_string_literal: true

module CustomerRequests
  class HeaderStatusResolver
    TERMINAL_STATUSES = %w[completed cancelled unfillable].freeze

    def self.call!(request)
      new(request).call!
    end

    def initialize(request)
      @request = request
    end

    def call!
      return request if TERMINAL_STATUSES.include?(request.status)

      lines = request.customer_request_lines.reload
      return request if lines.empty?

      new_status = derive_status(lines)
      return request if new_status == request.status

      request.update!(status: new_status)
      request
    end

    private

    attr_reader :request

    def derive_status(lines)
      active = lines.reject { |line| %w[cancelled unfillable].include?(line.status) }
      return "cancelled" if active.empty? && lines.all? { |l| l.status == "cancelled" }
      return "unfillable" if active.empty? && lines.any? { |l| l.status == "unfillable" }

      return "ready_for_pickup" if active.any? { |l| l.status == "ready_for_pickup" } &&
                                   active.all? { |l| %w[ready_for_pickup completed cancelled].include?(l.status) }
      return "partially_filled" if active.any? { |l| %w[partially_filled ready_for_pickup completed].include?(l.status) }
      return "ordered" if active.any? { |l| %w[ordered partially_filled].include?(l.status) }
      return "approved_to_order" if active.any? { |l| l.status == "approved" }
      return "awaiting_customer_response" if active.any? { |l| l.status == "awaiting_customer_response" }
      return "researching" if active.any? { |l| %w[researching matched].include?(l.status) }

      "new"
    end
  end
end
