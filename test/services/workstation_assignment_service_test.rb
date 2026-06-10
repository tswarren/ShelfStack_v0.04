# frozen_string_literal: true

require "test_helper"

class WorkstationAssignmentServiceTest < ActiveSupport::TestCase
  test "stores digest not raw token" do
    store = create_store!
    workstation = create_workstation!(store: store)
    user = create_user!
    cookies = ActionDispatch::Request.empty.cookie_jar

    WorkstationAssignmentService.assign!(
      workstation: workstation,
      assigned_by: user,
      cookies: cookies
    )

    raw = cookies[ShelfStack::WORKSTATION_COOKIE_NAME]
    assert raw.present?
    assignment = WorkstationAssignment.last
    assert_equal TokenDigest.digest(raw), assignment.assignment_token_digest
    assert_not_equal raw, assignment.assignment_token_digest
  end
end
