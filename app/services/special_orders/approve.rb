# frozen_string_literal: true

module SpecialOrders
  class Approve
    class ApproveError < StandardError; end

    def self.call!(special_order:, approved_by_user:)
      new(special_order:, approved_by_user:).call!
    end

    def initialize(special_order:, approved_by_user:)
      @special_order = special_order
      @approved_by_user = approved_by_user
    end

    def call!
      raise ApproveError, "Special order must be pending_match" unless special_order.status == "pending_match"
      raise ApproveError, "Variant is required" if special_order.product_variant.blank?

      SpecialOrder.transaction do
        special_order.update!(status: "approved", approved_at: Time.current)
        AuditEvents.record!(
          actor: approved_by_user,
          event_name: "special_order.approved",
          auditable: special_order,
          details: {}
        )
      end
      special_order
    end

    private

    attr_reader :special_order, :approved_by_user
  end
end
