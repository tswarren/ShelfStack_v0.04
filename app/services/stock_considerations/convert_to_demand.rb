# frozen_string_literal: true

module StockConsiderations
  class ConvertToDemand
    class ConvertError < StandardError; end

    def self.call!(consideration:, actor:, capture_intent: "buyer_replenishment", quantity: nil)
      new(consideration:, actor:, capture_intent:, quantity:).call!
    end

    def initialize(consideration:, actor:, capture_intent: "buyer_replenishment", quantity: nil)
      @consideration = consideration
      @actor = actor
      @capture_intent = capture_intent.to_s
      @quantity = quantity
    end

    def call!
      raise ConvertError, "Consideration is already terminal" if consideration.terminal?
      raise ConvertError, "Consideration already converted" if consideration.converted_demand_line.present?

      variant = consideration.product_variant
      raise ConvertError, "Variant is required to convert" if variant.blank?

      qty = quantity.presence || consideration.quantity_suggested.presence || 1

      demand_line = nil
      StockConsideration.transaction do
        demand_line = DemandLines::Create.call!(
          store: consideration.store,
          actor: actor,
          capture_intent: capture_intent,
          quantity: qty,
          variant: variant,
          notes: consideration.notes,
          stock_consideration: consideration
        )

        consideration.update!(
          status: "converted_to_demand",
          converted_by_user: actor,
          converted_at: Time.current,
          reviewed_by_user: actor,
          reviewed_at: Time.current
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "stock_consideration.converted",
          auditable: consideration,
          details: {
            "demand_line_id" => demand_line.id,
            "demand_number" => demand_line.demand_number
          }
        )
      end

      demand_line
    end

    private

    attr_reader :consideration, :actor, :capture_intent, :quantity
  end
end
