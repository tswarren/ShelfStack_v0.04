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
    when "captured" then "ss-status ss-status--pending"
    when "canceled", "expired" then "ss-status ss-status--inactive"
    else "ss-status"
    end
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
