# frozen_string_literal: true

class AuditEvents
  SNAPSHOT_EXCLUDED = %w[password_digest pin_digest].freeze
  CHANGE_EXCLUDED = %w[created_at updated_at].freeze

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

  def self.build_details(auditable:, event_name:, extra: {})
    return extra.compact if auditable.nil?

    suffix = event_name.to_s.split(".").last
    auto = case suffix
    when "created" then { "attributes" => snapshot(auditable) }
    when "updated" then { "changes" => format_changes(auditable.saved_changes) }
    when "deleted" then { "attributes" => snapshot(auditable) }
    when "inactivated", "reactivated" then { "active" => auditable.try(:active?) }
    else {}
    end

    extra.stringify_keys.merge(auto)
  end

  def self.snapshot(record)
    record.attributes.except("id", "created_at", "updated_at", *SNAPSHOT_EXCLUDED).compact
  end

  def self.format_changes(saved_changes)
    return {} if saved_changes.blank?

    saved_changes
      .except(*CHANGE_EXCLUDED)
      .transform_values { |from, to| { "from" => from, "to" => to } }
  end
end
