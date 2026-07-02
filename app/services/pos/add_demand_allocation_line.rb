# frozen_string_literal: true

module Pos
  class AddDemandAllocationLine
    Error = Class.new(StandardError)

    OPEN_TRANSACTION_STATUSES = %w[draft suspended].freeze

    def self.pickup_ready?(allocation, at: Time.current)
      return false if allocation.blank?

      allocation.active? &&
        allocation.on_hand? &&
        (allocation.expires_at.blank? || allocation.expires_at > at) &&
        !DemandLine::TERMINAL_STATUSES.include?(allocation.demand_line.status)
    end

    def self.claimed_on_other_open_transaction?(allocation, transaction:)
      PosTransactionLine.joins(:pos_transaction)
                        .where(demand_allocation_id: allocation.id)
                        .where(pos_transactions: { status: OPEN_TRANSACTION_STATUSES })
                        .where.not(pos_transaction_id: transaction.id)
                        .exists?
    end

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
      raise Error, "Allocation is not ready for pickup" unless self.class.pickup_ready?(allocation)
      raise Error, "Store mismatch" if allocation.store_id != transaction.store_id

      if transaction.pos_transaction_lines.exists?(demand_allocation_id: allocation.id)
        raise Error, "Allocation is already on this transaction"
      end

      if self.class.claimed_on_other_open_transaction?(allocation, transaction: transaction)
        raise Error, "Allocation is already on another open transaction"
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
