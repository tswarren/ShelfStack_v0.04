# frozen_string_literal: true

module CustomerRequests
  class UnfillableEligibility
    Result = Data.define(:allowed, :reasons)

    BLOCKED_LINE_STATUSES = %w[ordered partially_filled ready_for_pickup].freeze
    BLOCKED_SPECIAL_ORDER_STATUSES = %w[ordered partially_received ready_for_pickup].freeze
    ACTIVE_RESERVATION_STATUSES = %w[active ready].freeze

    def self.check(request)
      new(request).check
    end

    def initialize(request)
      @request = request
    end

    def check
      reasons = []
      request.customer_request_lines.open_lines.each do |line|
        if BLOCKED_LINE_STATUSES.include?(line.status)
          reasons << "Line #{line.line_number} is #{line.status.tr('_', ' ')}"
        end

        if InventoryReservation.where(customer_request_line: line, status: ACTIVE_RESERVATION_STATUSES).exists?
          reasons << "Line #{line.line_number} has an active reservation"
        end

        special_order = line.special_order
        if special_order.present? && BLOCKED_SPECIAL_ORDER_STATUSES.include?(special_order.status)
          reasons << "Line #{line.line_number} has special order #{special_order.status.tr('_', ' ')}"
        end
      end

      Result.new(allowed: reasons.empty?, reasons: reasons)
    end

    private

    attr_reader :request
  end
end
