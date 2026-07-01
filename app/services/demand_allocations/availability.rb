# frozen_string_literal: true

module DemandAllocations
  class Availability
    def self.available_for_allocation(store:, variant:, balance: nil)
      new(store:, variant:, balance:).available_for_allocation
    end

    def self.available_for_sale_now(store:, variant:, balance: nil)
      new(store:, variant:, balance:).available_for_sale_now
    end

    def initialize(store:, variant:, balance: nil)
      @store = store
      @variant = variant
      @balance = balance
    end

    def available_for_allocation
      raw = balance_row.quantity_on_hand - balance_row.quantity_reserved - pending_pos_claims
      [ raw, 0 ].max
    end

    def available_for_sale_now
      balance_row.quantity_on_hand - balance_row.quantity_reserved - pending_pos_claims
    end

    private

    attr_reader :store, :variant, :balance

    def balance_row
      @balance_row ||= balance || InventoryBalance.find_or_initialize_by(store: store, product_variant: variant).tap do |row|
        row.quantity_on_hand ||= 0
        row.quantity_reserved ||= 0
        row.quantity_available ||= 0
      end
    end

    def pending_pos_claims
      0
    end
  end
end
