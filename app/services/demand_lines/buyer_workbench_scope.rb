# frozen_string_literal: true

module DemandLines
  class BuyerWorkbenchScope
    TAB_KEYS = %w[
      needs_ordering
      awaiting_vendor
      ready_for_po
      on_draft_po
      on_order
      received_pickup
      backordered
      all
    ].freeze

    TAB_LABELS = {
      "needs_ordering" => "Needs ordering",
      "awaiting_vendor" => "Awaiting vendor",
      "ready_for_po" => "Ready for PO",
      "on_draft_po" => "On draft PO",
      "on_order" => "On order",
      "received_pickup" => "Received / pickup",
      "backordered" => "Backordered",
      "all" => "All"
    }.freeze

    def self.apply(relation, tab_key, store:)
      new(relation, tab_key, store:).apply
    end

    def self.count(store:, tab_key:)
      apply(base_relation(store:), tab_key, store: store).distinct.count
    end

    def self.counts_for(store:)
      TAB_KEYS.index_with { |key| count(store: store, tab_key: key) }
    end

    def self.base_relation(store:)
      DemandLine.where(store: store)
                .where.not(status: DemandLine::TERMINAL_STATUSES)
                .includes(:customer, :product_variant, :product)
    end

    def initialize(relation, tab_key, store:)
      @relation = relation
      @tab_key = tab_key.to_s
      @store = store
    end

    def apply
      case @tab_key
      when "needs_ordering"
        apply_needs_ordering
      when "awaiting_vendor"
        QueueScope.apply(@relation, "awaiting_response", store: store)
      when "ready_for_po"
        apply_ready_for_po
      when "on_draft_po"
        apply_on_draft_po
      when "on_order"
        QueueScope.apply(@relation, "on_order", store: store)
      when "received_pickup"
        QueueScope.apply(@relation, "ready_for_pickup", store: store)
      when "backordered"
        QueueScope.apply(@relation, "vendor_backorder", store: store)
      else
        @relation
      end
    end

    private

    attr_reader :store

    def apply_needs_ordering
      approved_ids = QueueScope.apply(DemandLine.where(store: store), "approved_to_order", store: store).pluck(:id)
      special_order_ids = DemandLine.where(store: store, capture_intent: "special_order")
                                    .where(status: DemandLine::ALLOCATION_ACTIVE_STATUSES)
                                    .where.not(id: active_sourcing_run_demand_line_ids)
                                    .where.not(id: active_inbound_demand_line_ids)
                                    .pluck(:id)

      @relation.where(id: (approved_ids + special_order_ids).uniq)
    end

    def apply_ready_for_po
      confirmed_ids = VendorResponse.joins(sourcing_attempt: :sourcing_run)
                                    .where(sourcing_runs: { store_id: store.id })
                                    .where("vendor_responses.quantity_confirmed > 0")
                                    .select("DISTINCT sourcing_runs.demand_line_id")

      @relation.where(id: confirmed_ids)
               .where(status: DemandLine::ALLOCATION_ACTIVE_STATUSES)
               .where.not(id: active_inbound_demand_line_ids)
               .where.not(id: draft_plan_demand_line_ids)
    end

    def apply_on_draft_po
      @relation.where(id: draft_plan_demand_line_ids)
    end

    def draft_plan_demand_line_ids
      PurchaseOrderLineDemandPlan.active_plans
                                 .joins(:purchase_order)
                                 .merge(PurchaseOrder.drafts)
                                 .where(store_id: store.id)
                                 .select(:demand_line_id)
    end

    def active_sourcing_run_demand_line_ids
      SourcingRun.active_runs.where(store: store).select(:demand_line_id)
    end

    def active_inbound_demand_line_ids
      DemandAllocation.active_allocations
                      .inbound_kind
                      .where(store: store)
                      .select(:demand_line_id)
    end
  end
end
