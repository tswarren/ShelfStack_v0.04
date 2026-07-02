# frozen_string_literal: true

module SourcingHelper
  include DemandHelper
  RUN_STATUS_LABELS = {
    "open" => "Open",
    "partially_resolved" => "Partially resolved",
    "resolved" => "Resolved",
    "needs_review" => "Needs review",
    "canceled" => "Canceled"
  }.freeze

  ATTEMPT_STATUS_LABELS = {
    "pending" => "Pending",
    "submitted" => "Submitted",
    "confirmed" => "Confirmed",
    "partially_confirmed" => "Partially confirmed",
    "backordered" => "Backordered",
    "canceled" => "Canceled",
    "failed" => "Failed",
    "cascaded" => "Cascaded"
  }.freeze

  def sourcing_run_status_label(status)
    RUN_STATUS_LABELS.fetch(status.to_s, status.to_s.humanize)
  end

  def sourcing_run_status_class(status)
    case status.to_s
    when "open", "partially_resolved" then "ss-status ss-status--pending"
    when "needs_review" then "ss-status ss-status--warning"
    when "resolved" then "ss-status ss-status--active"
    when "canceled" then "ss-status ss-status--inactive"
    else "ss-status"
    end
  end

  def sourcing_attempt_status_label(status)
    ATTEMPT_STATUS_LABELS.fetch(status.to_s, status.to_s.humanize)
  end

  def sourcing_demand_intent_label(demand_line)
    demand_capture_intent_label(demand_line.capture_intent)
  end
end
