# frozen_string_literal: true

module StockConsiderations
  class Dismiss
    class DismissError < StandardError; end

    def self.call!(consideration:, actor:, dismiss_reason: nil, status: "dismissed")
      new(consideration:, actor:, dismiss_reason:, status:).call!
    end

    def initialize(consideration:, actor:, dismiss_reason: nil, status: "dismissed")
      @consideration = consideration
      @actor = actor
      @dismiss_reason = dismiss_reason
      @status = status.to_s
    end

    def call!
      raise DismissError, "Consideration is already terminal" if consideration.terminal?
      raise DismissError, "Invalid dismiss status" unless %w[dismissed duplicate already_carried].include?(status)

      StockConsideration.transaction do
        consideration.update!(
          status: status,
          dismissed_by_user: actor,
          dismissed_at: Time.current,
          dismiss_reason: dismiss_reason,
          reviewed_by_user: actor,
          reviewed_at: Time.current
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "stock_consideration.dismissed",
          auditable: consideration,
          details: { "status" => status, "dismiss_reason" => dismiss_reason }
        )
      end

      consideration
    end

    private

    attr_reader :consideration, :actor, :dismiss_reason, :status
  end
end
