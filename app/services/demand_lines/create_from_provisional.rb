# frozen_string_literal: true

module DemandLines
  class CreateFromProvisional
    class CreateError < StandardError; end

    def self.call!(**kwargs)
      new(**kwargs).call!
    end

    def initialize(store:, actor:, customer: nil, customer_name_snapshot: nil,
                   customer_email_snapshot: nil, customer_phone_snapshot: nil,
                   preferred_contact_method: nil, needed_by_date: nil, notes: nil,
                   provisional_title: nil, provisional_identifier: nil, provisional_creator: nil,
                   quantity: 1)
      @store = store
      @actor = actor
      @customer = customer
      @customer_name_snapshot = customer_name_snapshot
      @customer_email_snapshot = customer_email_snapshot
      @customer_phone_snapshot = customer_phone_snapshot
      @preferred_contact_method = preferred_contact_method
      @needed_by_date = needed_by_date
      @notes = notes
      @provisional_title = provisional_title
      @provisional_identifier = provisional_identifier
      @provisional_creator = provisional_creator
      @quantity = quantity
    end

    def call!
      Create.call!(
        store: store,
        actor: actor,
        capture_intent: "research",
        quantity: quantity,
        customer: customer,
        customer_name_snapshot: customer_name_snapshot,
        customer_email_snapshot: customer_email_snapshot,
        customer_phone_snapshot: customer_phone_snapshot,
        preferred_contact_method: preferred_contact_method,
        needed_by_date: needed_by_date,
        notes: notes,
        provisional_title: provisional_title,
        provisional_identifier: provisional_identifier,
        provisional_creator: provisional_creator
      )
    end

    private

    attr_reader :store, :actor, :customer, :customer_name_snapshot, :customer_email_snapshot,
                :customer_phone_snapshot, :preferred_contact_method, :needed_by_date, :notes,
                :provisional_title, :provisional_identifier, :provisional_creator, :quantity
  end
end
