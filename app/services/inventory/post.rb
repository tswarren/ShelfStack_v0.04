# frozen_string_literal: true

module Inventory
  class Post
    LinePayload = Data.define(
      :product_variant,
      :quantity_delta,
      :movement_type,
      :manual_unit_cost_cents,
      :cost_source,
      :inventory_location,
      :inventory_reason_code
    )

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(
      store:,
      posted_by_user:,
      posting_type:,
      source:,
      lines:,
      idempotency_key:,
      notes: nil,
      workstation: Current.workstation,
      posted_at: Time.current,
      reversal_of_posting: nil
    )
      @store = store
      @posted_by_user = posted_by_user
      @posting_type = posting_type
      @source = source
      @lines = lines
      @idempotency_key = idempotency_key
      @notes = notes
      @workstation = workstation
      @posted_at = posted_at
      @reversal_of_posting = reversal_of_posting
    end

    def call
      existing = InventoryPosting.find_by(source_type: source.class.name, source_id: source.id)
      return existing if existing

      InventoryPosting.transaction do
        lines.each { |line| Eligibility.ensure_eligible!(line.product_variant) }

        posting = InventoryPosting.create!(
          posting_type: posting_type,
          source: source,
          store: store,
          posted_at: posted_at,
          posted_by_user: posted_by_user,
          workstation: workstation,
          idempotency_key: idempotency_key,
          notes: notes,
          reversal_of_posting: reversal_of_posting
        )

        reversal_of_posting&.update!(reversed_by_posting: posting)

        lines.each_with_index do |line, index|
          valuation = CostEstimator.estimate(
            variant: line.product_variant,
            quantity_delta: line.quantity_delta,
            manual_unit_cost_cents: line.manual_unit_cost_cents,
            cost_source: line.cost_source
          )

          InventoryLedgerEntry.create!(
            inventory_posting: posting,
            line_number: index + 1,
            product_variant: line.product_variant,
            store: store,
            inventory_location: line.inventory_location,
            movement_type: line.movement_type,
            quantity_delta: line.quantity_delta,
            unit_cost_cents: valuation.unit_cost_cents,
            total_cost_cents: valuation.total_cost_cents,
            unit_retail_cents: valuation.unit_retail_cents,
            total_retail_cents: valuation.total_retail_cents,
            cost_source: valuation.cost_source,
            retail_source: valuation.retail_source,
            inventory_reason_code: line.inventory_reason_code,
            occurred_at: posted_at
          )

          BalanceUpdater.apply!(
            store: store,
            variant: line.product_variant,
            quantity_delta: line.quantity_delta,
            valuation: valuation,
            posting: posting
          )
        end

        AuditEvents.record!(
          actor: posted_by_user,
          event_name: "inventory_posting.created",
          auditable: posting,
          source: source,
          details: { "posting_type" => posting_type, "line_count" => lines.size }
        )

        posting
      end
    rescue ActiveRecord::RecordNotUnique
      InventoryPosting.find_by!(idempotency_key: idempotency_key)
    end

    private

    attr_reader :store, :posted_by_user, :posting_type, :source, :lines,
                :idempotency_key, :notes, :workstation, :posted_at, :reversal_of_posting
  end
end
