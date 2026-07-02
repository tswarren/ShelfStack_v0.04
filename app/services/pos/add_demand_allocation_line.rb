# frozen_string_literal: true

module Pos
  class AddDemandAllocationLine
    Error = Class.new(StandardError)

    def self.call!(transaction:, allocation:, added_by_user:, quantity: nil)
      new(transaction:, allocation:, added_by_user:, quantity:).call!
    end

    def initialize(transaction:, allocation:, added_by_user:, quantity: nil)
      @transaction = transaction
      @allocation = allocation
      @added_by_user = added_by_user
      @quantity = quantity.nil? ? allocation.quantity_allocated.to_i : quantity.to_i
    end

    def call!
      raise Error, "Allocation must be active" unless allocation.active?
      raise Error, "Allocation must be on-hand" unless allocation.on_hand?
      raise Error, "Store mismatch" if allocation.store_id != transaction.store_id
      raise Error, "Allocation is expired" if allocation.expires_at.present? && allocation.expires_at <= Time.current
      raise Error, "Demand line is terminal" if DemandLine::TERMINAL_STATUSES.include?(allocation.demand_line.status)

      if transaction.pos_transaction_lines.exists?(demand_allocation_id: allocation.id)
        raise Error, "Allocation is already on this transaction"
      end

      if quantity != allocation.quantity_allocated
        raise Error, "Pickup quantity must match allocated quantity"
      end

      variant = allocation.product_variant
      line = transaction.pos_transaction_lines.create!(
        line_number: next_line_number,
        line_type: "variant",
        product_variant: variant,
        product: variant.product,
        quantity: quantity,
        unit_price_cents: variant.selling_price_cents,
        line_discount_cents: 0,
        extended_price_cents: 0,
        tax_cents: 0,
        demand_allocation: allocation
      )

      customer = allocation.demand_line.customer
      transaction.update!(customer: customer) if customer.present?

      Pos::RecalculateTransaction.call!(transaction.reload)
      line
    end

    private

    attr_reader :transaction, :allocation, :added_by_user, :quantity

    def next_line_number
      (transaction.pos_transaction_lines.maximum(:line_number) || 0) + 1
    end
  end
end
