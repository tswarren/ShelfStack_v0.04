# frozen_string_literal: true

module DemandLines
  class StartFromItem
    class StartError < StandardError; end

    StartResult = Data.define(:demand_line, :allocation_result)

    CAPTURE_INTENTS = DemandLine::CAPTURE_INTENTS.freeze
    DEFAULT_HOLD_EXPIRY_DAYS = 14

    def self.call!(store:, variant:, actor:, capture_intent:, quantity: 1, customer: nil,
                   customer_name_snapshot: nil, customer_email_snapshot: nil, customer_phone_snapshot: nil,
                   preferred_contact_method: nil, needed_by_date: nil, notes: nil, expires_at: nil)
      new(
        store:, variant:, actor:, capture_intent:, quantity:, customer:,
        customer_name_snapshot:, customer_email_snapshot:, customer_phone_snapshot:,
        preferred_contact_method:, needed_by_date:, notes:, expires_at:
      ).call!
    end

    def initialize(store:, variant:, actor:, capture_intent:, quantity: 1, customer: nil,
                   customer_name_snapshot: nil, customer_email_snapshot: nil, customer_phone_snapshot: nil,
                   preferred_contact_method: nil, needed_by_date: nil, notes: nil, expires_at: nil)
      @store = store
      @variant = variant
      @actor = actor
      @capture_intent = capture_intent.to_s
      @quantity = quantity
      @customer = customer
      @customer_name_snapshot = customer_name_snapshot
      @customer_email_snapshot = customer_email_snapshot
      @customer_phone_snapshot = customer_phone_snapshot
      @preferred_contact_method = preferred_contact_method
      @needed_by_date = needed_by_date
      @notes = notes
      @expires_at = expires_at
    end

    def call!
      raise StartError, "Store is required" if store.blank?
      raise StartError, "Variant is required" if variant.blank?
      raise StartError, "Invalid capture intent" unless CAPTURE_INTENTS.include?(capture_intent)
      raise StartError, "Quantity must be positive" unless quantity.to_i.positive?

      resolved_expires_at = expires_at
      if capture_intent == "hold" && resolved_expires_at.blank?
        resolved_expires_at = DEFAULT_HOLD_EXPIRY_DAYS.days.from_now
      end

      demand_line = Create.call!(
        store: store,
        actor: actor,
        capture_intent: capture_intent,
        quantity: quantity,
        variant: variant,
        customer: customer,
        customer_name_snapshot: customer_name_snapshot,
        customer_email_snapshot: customer_email_snapshot,
        customer_phone_snapshot: customer_phone_snapshot,
        preferred_contact_method: preferred_contact_method,
        needed_by_date: needed_by_date,
        expires_at: resolved_expires_at,
        notes: notes
      )

      allocation_result = nil
      if capture_intent == "hold"
        allocation_result = allocate_hold_if_possible(demand_line)
        demand_line.reload
      end

      StartResult.new(demand_line: demand_line, allocation_result: allocation_result)
    end

    private

    attr_reader :store, :variant, :actor, :capture_intent, :quantity, :customer,
                :customer_name_snapshot, :customer_email_snapshot, :customer_phone_snapshot,
                :preferred_contact_method, :needed_by_date, :notes, :expires_at

    def allocate_hold_if_possible(demand_line)
      available = DemandAllocations::Availability.available_for_allocation(store: store, variant: variant)
      return :none if available <= 0

      unallocated = DemandAllocations::AllocationQuantities.for_demand_line(demand_line)[:unallocated_quantity]
      qty = [ quantity.to_i, available, unallocated ].min
      return :none if qty <= 0

      begin
        DemandAllocations::AllocateOnHand.call!(demand_line: demand_line, actor: actor, quantity: qty)
      rescue DemandAllocations::AllocateOnHand::AllocateError => e
        return :none if e.message.start_with?("Insufficient available quantity")

        raise
      end

      demand_line.reload
      if qty >= demand_line.quantity_requested
        :full
      else
        :partial
      end
    end
  end
end
