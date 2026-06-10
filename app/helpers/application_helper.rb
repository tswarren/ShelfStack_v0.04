# frozen_string_literal: true

module ApplicationHelper
  def display_time(timestamp)
    return "—" if timestamp.blank?

    timestamp.in_time_zone(Current.time_zone).strftime("%Y-%m-%d %H:%M %Z")
  end

  def status_label(active)
    active ? "Active" : "Inactive"
  end

  def status_class(active)
    active ? "status-active" : "status-inactive"
  end

  def session_status_label(status)
    status.to_s.humanize
  end
end
