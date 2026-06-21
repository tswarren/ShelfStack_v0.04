# frozen_string_literal: true

module SpecialOrders
  class AttachToPurchaseOrderLine
    class AttachError < StandardError; end

    def self.call!(special_order:, purchase_order_line:, quantity:, attached_by_user:)
      new(special_order:, purchase_order_line:, quantity:, attached_by_user:).call!
    end

    def initialize(special_order:, purchase_order_line:, quantity:, attached_by_user:)
      @special_order = special_order
      @purchase_order_line = purchase_order_line
      @quantity = quantity
      @attached_by_user = attached_by_user
    end

    def call!
      raise AttachError, "Quantity must be positive" unless quantity.positive?
      raise AttachError, "Variant mismatch" if special_order.product_variant_id != purchase_order_line.product_variant_id

      allocation = nil
      PurchaseOrderLineAllocation.transaction do
        allocation = Purchasing::AllocateCustomerDemandToPoLine.call!(
          purchase_order_line: purchase_order_line,
          special_order: special_order,
          quantity: quantity,
          allocated_by_user: attached_by_user
        )

        special_order.update!(status: "ordered", ordered_at: Time.current, quantity_ordered: special_order.quantity_ordered + quantity)
        line = special_order.customer_request_line
        line.update!(status: "ordered", ordered_quantity: line.ordered_quantity + quantity) if line.present?
        line&.customer_request&.refresh_status_from_lines!

        InventoryReservations::ReserveIncoming.call!(
          store: special_order.store,
          variant: special_order.product_variant,
          quantity: quantity,
          purchase_order_line: purchase_order_line,
          reserved_by_user: attached_by_user,
          customer: special_order.customer,
          customer_request_line: special_order.customer_request_line,
          special_order: special_order
        )

        AuditEvents.record!(
          actor: attached_by_user,
          event_name: "special_order.attached_to_po",
          auditable: special_order,
          details: {
            "purchase_order_line_id" => purchase_order_line.id,
            "quantity" => quantity
          }
        )
      end
      allocation
    end

    private

    attr_reader :special_order, :purchase_order_line, :quantity, :attached_by_user
  end
end
