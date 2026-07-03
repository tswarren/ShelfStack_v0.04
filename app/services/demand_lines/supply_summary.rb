# frozen_string_literal: true

module DemandLines
  class SupplySummary
    Row = Data.define(
      :label,
      :value,
      :kind
    )

    Summary = Data.define(
      :requested_quantity,
      :fulfilled_quantity,
      :active_allocated_quantity,
      :unallocated_quantity,
      :on_hand_available,
      :on_hand_reserved,
      :on_hand_allocated_to_demand,
      :inbound_available,
      :inbound_allocated_to_demand,
      :vendor_backorder_quantity,
      :planned_on_draft_po_quantity,
      :primary_supply_state,
      :rows
    )

    SUPPLY_STATES = {
      unallocated: "Unallocated",
      planned_on_po_draft: "Planned on order",
      allocated_inbound: "On order",
      allocated_on_hand: "On hand",
      vendor_backorder: "Vendor backorder",
      fulfilled: "Fulfilled"
    }.freeze

    def self.for(demand_line:, store:)
      new(demand_line:, store:).call
    end

    def initialize(demand_line:, store:)
      @demand_line = demand_line
      @store = store
    end

    def call
      quantities = DemandAllocations::AllocationQuantities.for_demand_line(demand_line)
      variant = demand_line.product_variant
      balance = variant.present? ? InventoryBalance.find_by(store: store, product_variant: variant) : nil

      on_hand_available = if variant.present?
        DemandAllocations::Availability.available_for_allocation(store: store, variant: variant, balance: balance)
      else
        0
      end

      inbound_available = eligible_inbound_available(variant)
      on_hand_allocated = active_qty_for_kind("on_hand")
      inbound_allocated = active_qty_for_kind("inbound_purchase_order")
      vendor_backorder = active_qty_for_kind("vendor_backorder")
      planned_draft = 0

      Summary.new(
        requested_quantity: demand_line.quantity_requested,
        fulfilled_quantity: quantities[:fulfilled_quantity],
        active_allocated_quantity: quantities[:active_allocated_quantity],
        unallocated_quantity: quantities[:unallocated_quantity],
        on_hand_available: on_hand_available,
        on_hand_reserved: balance&.quantity_reserved.to_i,
        on_hand_allocated_to_demand: on_hand_allocated,
        inbound_available: inbound_available,
        inbound_allocated_to_demand: inbound_allocated,
        vendor_backorder_quantity: vendor_backorder,
        planned_on_draft_po_quantity: planned_draft,
        primary_supply_state: primary_supply_state(
          quantities: quantities,
          on_hand_allocated: on_hand_allocated,
          inbound_allocated: inbound_allocated,
          vendor_backorder: vendor_backorder,
          planned_draft: planned_draft
        ),
        rows: build_rows(
          quantities: quantities,
          on_hand_available: on_hand_available,
          balance: balance,
          inbound_available: inbound_available,
          inbound_allocated: inbound_allocated,
          vendor_backorder: vendor_backorder,
          planned_draft: planned_draft
        )
      )
    end

    private

    attr_reader :demand_line, :store

    def active_qty_for_kind(kind)
      demand_line.demand_allocations.active_allocations.where(allocation_kind: kind).sum(:quantity_allocated)
    end

    def eligible_inbound_available(variant)
      return 0 if variant.blank?

      eligible_inbound_lines(variant).sum { |line| DemandAllocations::InboundAvailability.new(purchase_order_line: line).available_for }
    end

    def eligible_inbound_lines(variant)
      PurchaseOrderLine.joins(:purchase_order)
                       .where(purchase_orders: { store_id: store.id })
                       .where(product_variant_id: variant.id)
                       .merge(PurchaseOrder.submitted_records)
                       .where(status: DemandAllocations::InboundAvailability::ELIGIBLE_PO_LINE_STATUSES)
                       .select { |line| DemandAllocations::InboundAvailability.new(purchase_order_line: line).eligible? }
    end

    def primary_supply_state(quantities:, on_hand_allocated:, inbound_allocated:, vendor_backorder:, planned_draft: _planned_draft)
      return :fulfilled if quantities[:fulfilled_quantity] >= demand_line.quantity_requested
      return :allocated_on_hand if ready_for_pickup?
      return :vendor_backorder if vendor_backorder.positive? && quantities[:unallocated_quantity].positive?
      return :allocated_inbound if inbound_allocated.positive?
      return :allocated_on_hand if on_hand_allocated.positive?

      :unallocated
    end

    def ready_for_pickup?
      demand_line.demand_allocations.active_allocations.on_hand_kind
                 .where("expires_at IS NULL OR expires_at > ?", Time.current)
                 .exists?
    end

    def build_rows(quantities:, on_hand_available:, balance:, inbound_available:, inbound_allocated:, vendor_backorder:, planned_draft:)
      [
        Row.new(label: "Requested", value: quantities[:requested_quantity], kind: :quantity),
        Row.new(label: "Fulfilled", value: quantities[:fulfilled_quantity], kind: :quantity),
        Row.new(label: "Active allocated", value: quantities[:active_allocated_quantity], kind: :quantity),
        Row.new(label: "Unallocated", value: quantities[:unallocated_quantity], kind: :quantity),
        Row.new(label: "On hand available", value: on_hand_available, kind: :availability),
        Row.new(label: "On hand reserved (store)", value: balance&.quantity_reserved.to_i, kind: :availability),
        Row.new(label: "Inbound available", value: inbound_available, kind: :availability),
        Row.new(label: "Inbound allocated", value: inbound_allocated, kind: :allocation),
        Row.new(label: "Vendor backorder", value: vendor_backorder, kind: :allocation)
      ]
    end
  end
end
