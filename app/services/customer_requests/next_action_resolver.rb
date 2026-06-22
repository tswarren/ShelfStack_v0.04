# frozen_string_literal: true

module CustomerRequests
  class NextActionResolver
    Action = Data.define(:label, :path)

    EXPIRING_HOLD_WINDOW = QueueScope::EXPIRING_HOLD_WINDOW

    def self.for_line(line, store:, customer_request: nil, active_hold: nil, availability: nil)
      request = customer_request || line.customer_request
      holds = active_hold.present? ? { line.id => active_hold } : {}
      availability_by_variant = if availability.present? && line.product_variant_id.present?
        { line.product_variant_id => availability }
      else
        {}
      end

      new(
        request,
        store:,
        active_holds_by_line: holds,
        availability_by_variant: availability_by_variant
      ).resolve_for_line(line)
    end

    def self.for_request(request, store:, active_holds_by_line: {}, availability_by_variant: {})
      new(request, store:, active_holds_by_line:, availability_by_variant:).resolve
    end

    def initialize(request, store:, active_holds_by_line:, availability_by_variant:)
      @request = request
      @store = store
      @active_holds_by_line = active_holds_by_line
      @availability_by_variant = availability_by_variant
    end

    def resolve
      line = most_urgent_line
      return default_action if line.blank?

      action_for_line(line)
    end

    def resolve_for_line(line)
      return default_action if line.blank?
      return default_action if terminal_line?(line)

      action_for_line(line)
    end

    private

    attr_reader :request, :store, :active_holds_by_line, :availability_by_variant

    def most_urgent_line
      open_lines = request.customer_request_lines.reject { |line| terminal_line?(line) }
      return if open_lines.empty?

      open_lines.min_by { |line| [ line_priority(line), line.line_number ] }
    end

    def line_priority(line)
      return 0 if line.product_variant_id.blank?
      return 1 if expiring_hold?(line)
      return 2 if line.status == "ready_for_pickup"
      return 3 if line.special_order&.status == "approved"
      return 4 if line.request_type == "special_order" && line.special_order.blank?
      return 5 if notify_ready?(line)
      return 6 if line.status == "awaiting_customer_response"
      return 7 if line.request_type == "research" && line.matched?
      8
    end

    def action_for_line(line)
      path = request_path(line)

      if line.product_variant_id.blank?
        return Action.new(label: "Match item", path: path)
      end

      if expiring_hold?(line)
        return Action.new(label: "Hold expiring", path: path)
      end

      if line.status == "ready_for_pickup"
        return Action.new(label: "Ready for pickup", path: path)
      end

      if line.special_order&.status == "approved"
        return Action.new(label: "Attach to PO", path: path)
      end

      if line.request_type == "special_order" && line.special_order.blank?
        return Action.new(label: "Create special order", path: path)
      end

      if notify_ready?(line)
        return Action.new(label: "Notify customer", path: path)
      end

      if line.status == "awaiting_customer_response"
        return Action.new(label: "Record contact", path: path)
      end

      if line.request_type == "research" && line.matched?
        return Action.new(label: "Convert type", path: path)
      end

      Action.new(label: "View request", path: request_path)
    end

    def notify_ready?(line)
      return false unless line.request_type == "notify" && line.matched?

      NotifyQueueQuery.qualifies?(line, store: store)
    end

    def expiring_hold?(line)
      hold = active_holds_by_line[line.id]
      return false if hold.blank? || hold.expires_at.blank?

      hold.expires_at <= EXPIRING_HOLD_WINDOW.from_now
    end

    def terminal_line?(line)
      %w[completed cancelled unfillable].include?(line.status)
    end

    def request_path(line = nil)
      if line.present?
        Rails.application.routes.url_helpers.customers_customer_request_path(request, anchor: "line-#{line.id}")
      else
        Rails.application.routes.url_helpers.customers_customer_request_path(request)
      end
    end

    def default_action
      Action.new(label: "View request", path: request_path)
    end
  end
end
