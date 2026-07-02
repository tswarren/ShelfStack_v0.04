# frozen_string_literal: true

module Pos
  class DemandPickupLookup
    PickupRow = Data.define(
      :demand_allocation_id,
      :demand_line_id,
      :customer_id,
      :customer_name,
      :demand_number,
      :variant_sku,
      :variant_name,
      :quantity,
      :expires_at
    )

    def self.ready_for_store(store:, query: nil, demand_number: nil)
      new(store:, query:, demand_number:).ready_rows
    end

    def initialize(store:, query: nil, demand_number: nil)
      @store = store
      @query = query.to_s.strip
      @demand_number = demand_number.to_s.strip
    end

    def ready_rows
      scope = base_scope
      scope = filter_by_query(scope) if query.present?
      scope = filter_by_demand_number(scope) if demand_number.present?

      scope.map { |allocation| row_for(allocation) }
    end

    private

    attr_reader :store, :query, :demand_number

    def base_scope
      DemandAllocation.active_allocations
                      .on_hand_kind
                      .where(store: store)
                      .where("demand_allocations.expires_at IS NULL OR demand_allocations.expires_at > ?", Time.current)
                      .joins(:demand_line)
                      .merge(DemandLine.where.not(status: DemandLine::TERMINAL_STATUSES))
                      .includes(:product_variant, demand_line: :customer)
                      .order(Arel.sql("demand_allocations.expires_at ASC NULLS LAST"), "demand_allocations.allocated_at")
    end

    def filter_by_query(scope)
      customer_ids = Customer.active_records
                             .where("display_name ILIKE :q OR email ILIKE :q OR phone ILIKE :q", q: "%#{query}%")
                             .limit(25)
                             .pluck(:id)
      snapshot_scope = scope.joins(:demand_line)
                            .where(
                              "demand_lines.customer_name_snapshot ILIKE :q OR " \
                              "demand_lines.customer_email_snapshot ILIKE :q OR " \
                              "demand_lines.customer_phone_snapshot ILIKE :q",
                              q: "%#{query}%"
                            )

      scope.where(demand_lines: { customer_id: customer_ids }).or(snapshot_scope)
    end

    def filter_by_demand_number(scope)
      scope.joins(:demand_line)
           .where("demand_lines.demand_number ILIKE ?", "%#{demand_number}%")
    end

    def row_for(allocation)
      demand_line = allocation.demand_line

      PickupRow.new(
        demand_allocation_id: allocation.id,
        demand_line_id: demand_line.id,
        customer_id: demand_line.customer_id,
        customer_name: CustomerDemand::DisplayName.for_demand_line(demand_line),
        demand_number: demand_line.demand_number,
        variant_sku: allocation.product_variant.sku,
        variant_name: allocation.product_variant.name,
        quantity: allocation.quantity_allocated,
        expires_at: allocation.expires_at
      )
    end
  end
end
