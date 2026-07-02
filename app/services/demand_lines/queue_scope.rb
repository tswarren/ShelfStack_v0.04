# frozen_string_literal: true

module DemandLines
  class QueueScope
    EXPIRING_HOLD_WINDOW = 3.days

    QUEUE_FILTERS = {
      "ready_for_pickup" => { kind: :ready_for_pickup },
      "expiring_holds" => { kind: :expiring_holds },
      "notify_customer" => { kind: :notify_customer },
      "needs_research" => { kind: :needs_research },
      "awaiting_response" => { kind: :awaiting_response },
      "approved_to_order" => { kind: :approved_to_order },
      "on_order" => { kind: :on_order },
      "vendor_backorder" => { kind: :vendor_backorder },
      "completed" => { status: "fulfilled" },
      "cancelled" => { status: "canceled" },
      "expired" => { status: "expired" }
    }.freeze

    OPERATIONAL_QUEUE_KEYS = %w[
      ready_for_pickup
      expiring_holds
      notify_customer
      needs_research
      awaiting_response
      approved_to_order
      on_order
      vendor_backorder
    ].freeze

    QUEUE_KEYS = QUEUE_FILTERS.keys.freeze

    AWAITING_ATTEMPT_STATUSES = SourcingAttempt::STATUSES - %w[canceled cascaded]

    def self.apply(relation, queue_key, store:)
      new(relation, queue_key, store:).apply
    end

    def self.count(store:, queue_key:)
      apply(DemandLine.where(store: store), queue_key, store: store).distinct.count
    end

    def self.counts_for(store:)
      QUEUE_KEYS.index_with { |key| count(store: store, queue_key: key) }
    end

    def self.base_relation(store:)
      DemandLine.where(store: store)
    end

    def self.ready_for_pickup_relation(relation)
      relation.joins(:demand_allocations)
              .merge(active_on_hand_allocations)
              .where.not(status: DemandLine::TERMINAL_STATUSES)
              .where("demand_allocations.product_variant_id IS NOT NULL")
              .where("demand_allocations.quantity_allocated > 0")
              .distinct
    end

    def self.active_on_hand_allocations
      DemandAllocation.active_allocations
                      .on_hand_kind
                      .where("demand_allocations.expires_at IS NULL OR demand_allocations.expires_at > ?", Time.current)
    end

    def initialize(relation, queue_key, store:)
      @relation = relation
      @queue_key = queue_key.to_s
      @store = store
    end

    def apply
      filter = QUEUE_FILTERS[@queue_key]
      return @relation if filter.blank?

      case filter[:kind]
      when :ready_for_pickup
        self.class.ready_for_pickup_relation(@relation)
      when :expiring_holds
        apply_expiring_holds
      when :notify_customer
        apply_notify_customer
      when :needs_research
        apply_needs_research
      when :awaiting_response
        apply_awaiting_response
      when :approved_to_order
        apply_approved_to_order
      when :on_order
        apply_on_order
      when :vendor_backorder
        apply_vendor_backorder
      else
        @relation.where(status: filter[:status])
      end
    end

    private

    attr_reader :store

    def apply_expiring_holds
      self.class.ready_for_pickup_relation(@relation)
          .where(demand_allocations: { expires_at: ..EXPIRING_HOLD_WINDOW.from_now })
    end

    def apply_notify_customer
      @relation.where(capture_intent: "notify")
               .where(status: DemandLine::ALLOCATION_ACTIVE_STATUSES)
               .where(id: active_on_hand_demand_line_ids)
               .where.not(id: fully_fulfilled_demand_line_ids)
               .distinct
    end

    def apply_needs_research
      @relation.where(status: "captured")
    end

    def apply_awaiting_response
      pickup_ids = self.class.ready_for_pickup_relation(DemandLine.where(store: store)).select(:id)

      @relation.where(status: DemandLine::ALLOCATION_ACTIVE_STATUSES)
               .where.not(id: pickup_ids)
               .where(
                 "demand_lines.id IN (?) OR demand_lines.id IN (?)",
                 sourcing_run_demand_line_ids,
                 buyer_review_demand_line_ids
               )
               .distinct
    end

    def apply_approved_to_order
      submitted_attempt_ids = SourcingAttempt.where(store: store, status: "submitted").select(:demand_line_id)

      @relation.where(capture_intent: "special_order")
               .where(status: %w[open partially_allocated])
               .where.not(id: active_inbound_demand_line_ids)
               .where.not(id: active_vendor_backorder_demand_line_ids)
               .where.not(id: submitted_attempt_ids)
               .distinct
    end

    def apply_on_order
      @relation.joins(:demand_allocations)
               .merge(DemandAllocation.active_allocations.inbound_kind)
               .distinct
    end

    def apply_vendor_backorder
      @relation.joins(:demand_allocations)
               .merge(DemandAllocation.active_allocations.vendor_backorder_kind)
               .distinct
    end

    def active_on_hand_demand_line_ids
      DemandAllocation.active_allocations
                      .on_hand_kind
                      .joins(:demand_line)
                      .merge(DemandLine.where(store: store))
                      .select("demand_allocations.demand_line_id")
    end

    def fully_fulfilled_demand_line_ids
      DemandLine.where(store: store)
                .where(status: "fulfilled")
                .select(:id)
    end

    def sourcing_run_demand_line_ids
      SourcingRun.active_runs
                 .where(store: store)
                 .select(:demand_line_id)
    end

    def buyer_review_demand_line_ids
      SourcingAttempt.where(store: store, buyer_review_required: true)
                     .where.not(status: %w[canceled cascaded])
                     .select(:demand_line_id)
    end

    def active_inbound_demand_line_ids
      DemandAllocation.active_allocations
                      .inbound_kind
                      .where(store: store)
                      .select(:demand_line_id)
    end

    def active_vendor_backorder_demand_line_ids
      DemandAllocation.active_allocations
                      .vendor_backorder_kind
                      .where(store: store)
                      .select(:demand_line_id)
    end
  end
end
