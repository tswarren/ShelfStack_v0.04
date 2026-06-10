# frozen_string_literal: true

class AuditEvents
  def self.record!(actor:, event_name:, auditable: nil, source: nil, details: {})
    create!(
      actor: actor,
      event_name: event_name,
      auditable: auditable,
      source: source,
      details: details
    )
  end

  def self.create!(actor:, event_name:, auditable: nil, source: nil, details: {})
    AuditEvent.create!(
      actor_user: actor,
      event_name: event_name,
      auditable: auditable,
      source: source,
      store: Current.store,
      workstation: Current.workstation,
      user_session: Current.user_session,
      occurred_at: Time.current,
      event_details: details
    )
  end
end
