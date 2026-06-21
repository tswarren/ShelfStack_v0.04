# frozen_string_literal: true

module Purchasing
  class AllocateCustomerDemandToPoLine
    class AllocateError < StandardError; end

    def self.call!(purchase_order_line:, special_order:, quantity:, allocated_by_user:)
      new(purchase_order_line:, special_order:, quantity:, allocated_by_user:).call!
    end

    def initialize(purchase_order_line:, special_order:, quantity:, allocated_by_user:)
      @purchase_order_line = purchase_order_line
      @special_order = special_order
      @quantity = quantity
      @allocated_by_user = allocated_by_user
    end

    def call!
      existing = purchase_order_line.purchase_order_line_allocations.sum(:quantity_allocated)
      if existing + quantity > purchase_order_line.quantity_ordered
        raise AllocateError, "Allocation exceeds PO line quantity ordered"
      end

      allocation = PurchaseOrderLineAllocation.create!(
        purchase_order_line: purchase_order_line,
        special_order: special_order,
        customer_request_line: special_order.customer_request_line,
        quantity_allocated: quantity,
        status: "active"
      )

      AuditEvents.record!(
        actor: allocated_by_user,
        event_name: "purchase_order_line_allocation.created",
        auditable: allocation,
        details: { "quantity_allocated" => quantity }
      )
      allocation
    end

    private

    attr_reader :purchase_order_line, :special_order, :quantity, :allocated_by_user
  end
end
