# frozen_string_literal: true

module Pos
  class CompleteDemandAllocationFulfillment
    def self.call!(transaction:, fulfilled_by_user:)
      new(transaction:, fulfilled_by_user:).call!
    end

    def initialize(transaction:, fulfilled_by_user:)
      @transaction = transaction
      @fulfilled_by_user = fulfilled_by_user
    end

    def call!
      transaction.pos_transaction_lines.each do |line|
        next if line.demand_allocation_id.blank?

        allocation = line.demand_allocation
        next unless allocation.active?

        DemandAllocations::Fulfill.call!(
          allocation: allocation,
          actor: fulfilled_by_user,
          fulfillment_reference: line
        )
      end
    end

    private

    attr_reader :transaction, :fulfilled_by_user
  end
end
