# frozen_string_literal: true

module ApplicationHelper
  include SetupFormatHelper
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

  def role_assignment_scope_label(assignment)
    if assignment.global_scoped?
      "Global"
    else
      store = assignment.store
      store ? "#{store.name} (#{store.store_number})" : "Store"
    end
  end
end
