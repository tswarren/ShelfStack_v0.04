# frozen_string_literal: true

module DemandLines
  class StartFromItem
    class StartError < StandardError; end

    CAPTURE_INTENTS = DemandLine::CAPTURE_INTENTS.freeze

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

      Create.call!(
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
        expires_at: expires_at,
        notes: notes
      )
    end

    private

    attr_reader :store, :variant, :actor, :capture_intent, :quantity, :customer,
                :customer_name_snapshot, :customer_email_snapshot, :customer_phone_snapshot,
                :preferred_contact_method, :needed_by_date, :notes, :expires_at
  end
end
