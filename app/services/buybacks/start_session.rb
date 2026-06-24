# frozen_string_literal: true

module Buybacks
  class StartSession
    def self.call!(store:, customer:, actor:, workstation: nil, notes: nil)
      new(store:, customer:, actor:, workstation:, notes:).call!
    end

    def initialize(store:, customer:, actor:, workstation: nil, notes: nil)
      @store = store
      @customer = customer
      @actor = actor
      @workstation = workstation || Current.workstation
      @notes = notes
    end

    def call!
      raise ArgumentError, "Customer is required." if customer.blank?

      session = BuybackSession.create!(
        store: store,
        workstation: workstation,
        customer: customer,
        status: "draft",
        created_by_user: actor,
        notes: notes
      )

      AuditEvents.record!(
        actor: actor,
        event_name: "buyback.session.created",
        auditable: session
      )

      session
    end

    private

    attr_reader :store, :customer, :actor, :workstation, :notes
  end
end
