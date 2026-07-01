# frozen_string_literal: true

module StockConsiderations
  class Create
    class CreateError < StandardError; end

    def self.call!(store:, actor:, variant: nil, provisional_title: nil, provisional_identifier: nil,
                   provisional_creator: nil, reason: nil, priority: nil, quantity_suggested: nil, notes: nil)
      new(
        store:, actor:, variant:, provisional_title:, provisional_identifier:, provisional_creator:,
        reason:, priority:, quantity_suggested:, notes:
      ).call!
    end

    def initialize(store:, actor:, variant: nil, provisional_title: nil, provisional_identifier: nil,
                   provisional_creator: nil, reason: nil, priority: nil, quantity_suggested: nil, notes: nil)
      @store = store
      @actor = actor
      @variant = variant
      @provisional_title = provisional_title
      @provisional_identifier = provisional_identifier
      @provisional_creator = provisional_creator
      @reason = reason
      @priority = priority
      @quantity_suggested = quantity_suggested
      @notes = notes
    end

    def call!
      raise CreateError, "Title or variant is required" if variant.blank? && provisional_title.blank?

      consideration = nil
      StockConsideration.transaction do
        consideration = StockConsideration.create!(
          store: store,
          status: "open",
          product: variant&.product,
          product_variant: variant,
          provisional_title: provisional_title,
          provisional_identifier: provisional_identifier,
          provisional_creator: provisional_creator,
          reason: reason,
          priority: priority,
          quantity_suggested: quantity_suggested,
          notes: notes,
          created_by_user: actor
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "stock_consideration.created",
          auditable: consideration,
          details: { "product_variant_id" => variant&.id }
        )
      end

      consideration
    end

    private

    attr_reader :store, :actor, :variant, :provisional_title, :provisional_identifier,
                :provisional_creator, :reason, :priority, :quantity_suggested, :notes
  end
end
