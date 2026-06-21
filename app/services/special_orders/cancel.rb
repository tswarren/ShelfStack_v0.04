# frozen_string_literal: true

module SpecialOrders
  class Cancel
    class CancelError < StandardError; end

    def self.call!(special_order:, cancelled_by_user:, reason: nil)
      new(special_order:, cancelled_by_user:, reason:).call!
    end

    def initialize(special_order:, cancelled_by_user:, reason: nil)
      @special_order = special_order
      @cancelled_by_user = cancelled_by_user
      @reason = reason
    end

    def call!
      SpecialOrder.transaction do
        special_order.update!(
          status: "cancelled",
          cancelled_at: Time.current,
          quantity_cancelled: special_order.remaining_committed
        )
        line = special_order.customer_request_line
        line.update!(status: "cancelled", cancelled_quantity: line.remaining_quantity) if line.present?
        line&.customer_request&.refresh_status_from_lines!

        AuditEvents.record!(
          actor: cancelled_by_user,
          event_name: "special_order.cancelled",
          auditable: special_order,
          details: { "reason" => reason }
        )
      end
      special_order
    end

    private

    attr_reader :special_order, :cancelled_by_user, :reason
  end
end
