# frozen_string_literal: true

require "test_helper"

class AuditEventTest < ActiveSupport::TestCase
  test "audit events are append only" do
    user = create_user!
    event = AuditEvent.create!(
      actor_user: user,
      event_name: "user.login",
      occurred_at: Time.current,
      event_details: {}
    )
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      event.update!(event_name: "changed")
    end
  end
end
