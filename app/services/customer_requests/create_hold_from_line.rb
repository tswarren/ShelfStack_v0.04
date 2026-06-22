# frozen_string_literal: true

module CustomerRequests
  class CreateHoldFromLine
    class HoldError < StandardError; end

    def self.call!(request:, line:, store:, actor:, quantity: nil, expires_at: nil,
                   override_authorized_by_user: nil, override_reason: nil)
      new(
        request:, line:, store:, actor:, quantity:, expires_at:,
        override_authorized_by_user:, override_reason:
      ).call!
    end

    def initialize(request:, line:, store:, actor:, quantity: nil, expires_at: nil,
                   override_authorized_by_user: nil, override_reason: nil)
      @request = request
      @line = line
      @store = store
      @actor = actor
      @quantity = quantity
      @expires_at = expires_at
      @override_authorized_by_user = override_authorized_by_user
      @override_reason = override_reason
    end

    def call!
      raise HoldError, "Line must be matched" unless line.matched?

      reserve_qty = quantity.presence&.to_i || line.requested_quantity
      parsed_expires_at = expires_at.present? ? Time.zone.parse(expires_at.to_s) : nil

      reservation = InventoryReservations::ReserveOnHand.call!(
        store: store,
        variant: line.product_variant,
        quantity: reserve_qty,
        reserved_by_user: actor,
        customer: request.customer,
        customer_request_line: line,
        expires_at: parsed_expires_at,
        override_authorized_by_user: override_authorized_by_user,
        override_reason: override_reason
      )
      line.update!(status: "ready_for_pickup")
      request.refresh_status_from_lines!

      AuditEvents.record!(
        actor: actor,
        event_name: "inventory_reservation.created",
        auditable: reservation,
        source: request,
        details: { "customer_request_line_id" => line.id, "quantity" => reserve_qty }
      )

      reservation
    end

    private

    attr_reader :request, :line, :store, :actor, :quantity, :expires_at,
                :override_authorized_by_user, :override_reason
  end
end
