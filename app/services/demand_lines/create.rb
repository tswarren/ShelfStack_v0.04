# frozen_string_literal: true

module DemandLines
  class Create
    class CreateError < StandardError; end

    def self.call!(store:, actor:, capture_intent:, quantity: 1, variant: nil, customer: nil,
                   customer_name_snapshot: nil, customer_email_snapshot: nil, customer_phone_snapshot: nil,
                   preferred_contact_method: nil, needed_by_date: nil, expires_at: nil, notes: nil,
                   stock_consideration: nil, source: nil, purpose: nil, status: nil,
                   provisional_title: nil, provisional_identifier: nil, provisional_creator: nil)
      new(
        store:, actor:, capture_intent:, quantity:, variant:, customer:,
        customer_name_snapshot:, customer_email_snapshot:, customer_phone_snapshot:,
        preferred_contact_method:, needed_by_date:, expires_at:, notes:,
        stock_consideration:, source:, purpose:, status:,
        provisional_title:, provisional_identifier:, provisional_creator:
      ).call!
    end

    def initialize(store:, actor:, capture_intent:, quantity: 1, variant: nil, customer: nil,
                   customer_name_snapshot: nil, customer_email_snapshot: nil, customer_phone_snapshot: nil,
                   preferred_contact_method: nil, needed_by_date: nil, expires_at: nil, notes: nil,
                   stock_consideration: nil, source: nil, purpose: nil, status: nil,
                   provisional_title: nil, provisional_identifier: nil, provisional_creator: nil)
      @store = store
      @actor = actor
      @capture_intent = capture_intent.to_s
      @quantity = quantity.to_i
      @variant = variant
      @customer = customer
      @customer_name_snapshot = customer_name_snapshot
      @customer_email_snapshot = customer_email_snapshot
      @customer_phone_snapshot = customer_phone_snapshot
      @preferred_contact_method = preferred_contact_method
      @needed_by_date = needed_by_date
      @expires_at = expires_at
      @notes = notes
      @stock_consideration = stock_consideration
      @source = source
      @purpose = purpose
      @status = status
      @provisional_title = provisional_title
      @provisional_identifier = provisional_identifier
      @provisional_creator = provisional_creator
    end

    def call!
      mapping = IntentMapping.fetch(capture_intent)
      raise CreateError, "Invalid capture intent" if mapping.blank?

      resolved_source = source.presence || mapping.source
      resolved_purpose = purpose.presence || mapping.purpose
      resolved_status = status.presence || mapping.initial_status

      eligibility = EligibilityResolver.call(
        capture_intent: capture_intent,
        variant: variant,
        customer: customer,
        customer_name_snapshot: resolved_customer_name_snapshot,
        source: resolved_source,
        purpose: resolved_purpose
      )
      if !eligibility.allowed
        raise CreateError, eligibility.blocking_reasons.map(&:message).join("; ")
      end

      raise CreateError, "Quantity must be positive" unless quantity.positive?

      demand_line = nil
      DemandLine.transaction do
        demand_line = DemandLine.create!(
          store: store,
          demand_number: NumberAllocator.next_for!(store: store),
          source: resolved_source,
          purpose: resolved_purpose,
          capture_intent: capture_intent,
          status: resolved_status,
          product: variant&.product,
          product_variant: variant,
          customer: customer,
          customer_name_snapshot: resolved_customer_name_snapshot,
          customer_email_snapshot: resolved_customer_email_snapshot,
          customer_phone_snapshot: resolved_customer_phone_snapshot,
          preferred_contact_method: preferred_contact_method,
          quantity_requested: quantity,
          needed_by_date: needed_by_date,
          expires_at: expires_at,
          notes: notes,
          provisional_title: provisional_title,
          provisional_identifier: provisional_identifier,
          provisional_creator: provisional_creator,
          stock_consideration: stock_consideration,
          created_by_user: actor,
          matched_by_user: variant.present? && resolved_status == "open" ? actor : nil,
          matched_at: variant.present? && resolved_status == "open" ? Time.current : nil
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "demand_line.created",
          auditable: demand_line,
          details: {
            "demand_number" => demand_line.demand_number,
            "capture_intent" => capture_intent,
            "product_variant_id" => variant&.id
          }
        )
      end

      demand_line
    end

    private

    attr_reader :store, :actor, :capture_intent, :quantity, :variant, :customer,
                :customer_name_snapshot, :customer_email_snapshot, :customer_phone_snapshot,
                :preferred_contact_method, :needed_by_date, :expires_at, :notes,
                :stock_consideration, :source, :purpose, :status,
                :provisional_title, :provisional_identifier, :provisional_creator

    def resolved_customer_name_snapshot
      customer&.display_name || customer_name_snapshot
    end

    def resolved_customer_email_snapshot
      customer&.email || customer_email_snapshot
    end

    def resolved_customer_phone_snapshot
      customer&.phone || customer_phone_snapshot
    end
  end
end
