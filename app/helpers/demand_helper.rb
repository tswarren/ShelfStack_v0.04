# frozen_string_literal: true

module DemandHelper
  CAPTURE_INTENT_LABELS = {
    "hold" => "Hold request",
    "notify" => "Notify",
    "special_order" => "Special order",
    "research" => "Research",
    "manual_tbo" => "Manual TBO",
    "used_wanted" => "Used wanted",
    "buyer_replenishment" => "Buyer replenishment"
  }.freeze

  STATUS_LABELS = {
    "captured" => "Captured",
    "open" => "Open",
    "partially_allocated" => "Partially allocated",
    "allocated" => "Allocated",
    "fulfilled" => "Fulfilled",
    "canceled" => "Canceled",
    "expired" => "Expired"
  }.freeze

  def demand_capture_intent_label(intent)
    CAPTURE_INTENT_LABELS.fetch(intent.to_s, intent.to_s.humanize)
  end

  def demand_status_label(status)
    STATUS_LABELS.fetch(status.to_s, status.to_s.humanize)
  end

  def demand_status_class(status)
    case status.to_s
    when "open" then "ss-status ss-status--active"
    when "partially_allocated", "allocated" then "ss-status ss-status--pending"
    when "captured" then "ss-status ss-status--pending"
    when "fulfilled" then "ss-status ss-status--active"
    when "canceled", "expired" then "ss-status ss-status--inactive"
    else "ss-status"
    end
  end

  def demand_allocation_summary(demand_line)
    DemandAllocations::AllocationQuantities.for_demand_line(demand_line)
  end

  def demand_allocation_state_label(demand_line)
    quantities = demand_allocation_summary(demand_line)
    if quantities[:fulfilled_quantity] >= demand_line.quantity_requested
      "Fulfilled"
    elsif quantities[:active_allocated_quantity].positive?
      "#{quantities[:active_allocated_quantity]} of #{demand_line.quantity_requested} allocated"
    else
      "Unallocated"
    end
  end

  def demand_allocation_kind_label(kind)
    {
      "on_hand" => "On hand",
      "inbound_purchase_order" => "Inbound PO",
      "vendor_backorder" => "Vendor backorder"
    }.fetch(kind.to_s, kind.to_s.humanize)
  end

  def demand_supply_state_label(state)
    DemandLines::SupplySummary::SUPPLY_STATES.fetch(state.to_sym, state.to_s.humanize)
  end

  def demand_supply_summary(demand_line, store:)
    DemandLines::SupplySummary.for(demand_line:, store:)
  end

  def demand_item_label(demand_line)
    if demand_line.product_variant.present?
      "#{demand_line.product_variant.sku} — #{demand_line.product_variant.name}"
    elsif demand_line.provisional_title.present?
      demand_line.provisional_title
    else
      "—"
    end
  end
end
