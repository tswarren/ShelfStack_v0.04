# frozen_string_literal: true

module SpecialOrders
  class CreateFromRequestLine
    class CreateError < StandardError; end

    def self.call!(line:, created_by_user:, quantity: nil, vendor: nil)
      new(line:, created_by_user:, quantity:, vendor:).call!
    end

    def initialize(line:, created_by_user:, quantity: nil, vendor: nil)
      @line = line
      @created_by_user = created_by_user
      @quantity = quantity
      @vendor = vendor
    end

    def call!
      raise CreateError, "Line must be matched" unless line.matched?
      raise CreateError, "Line must be special_order type" unless line.request_type == "special_order"
      raise CreateError, "Special order already exists" if line.special_order.present?

      request = line.customer_request
      raise CreateError, "Customer is required for special order" if request.customer.blank?

      qty = quantity || line.requested_quantity
      special_order = nil
      SpecialOrder.transaction do
        special_order = SpecialOrder.create!(
          store: request.store,
          customer: request.customer,
          customer_request_line: line,
          product_variant: line.product_variant,
          vendor: vendor,
          status: "pending_match",
          quantity_committed: qty,
          created_by_user: created_by_user
        )
        line.update!(status: "approved", approved_quantity: qty)

        AuditEvents.record!(
          actor: created_by_user,
          event_name: "special_order.created",
          auditable: special_order,
          details: { "quantity_committed" => qty }
        )
        request.refresh_status_from_lines!
      end
      special_order
    end

    private

    attr_reader :line, :created_by_user, :quantity, :vendor
  end
end
