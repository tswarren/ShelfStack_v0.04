# frozen_string_literal: true

class WorkstationAssignmentService
  class Error < StandardError; end

  def self.resolve_from_cookie(cookies)
    raw_token = cookies[ShelfStack::WORKSTATION_COOKIE_NAME]
    return nil if raw_token.blank?

    assignment = WorkstationAssignment.active_records.find_by(
      assignment_token_digest: TokenDigest.digest(raw_token)
    )
    return nil unless assignment
    return nil unless assignment.workstation.active?
    return nil unless assignment.workstation.store.active?

    assignment.touch_last_seen!
    assignment
  end

  def self.assign!(workstation:, assigned_by:, cookies:)
    revoke_active_for_workstation!(workstation)

    raw_token = TokenDigest.generate
    assignment = WorkstationAssignment.create!(
      workstation: workstation,
      assignment_token_digest: TokenDigest.digest(raw_token),
      assigned_by_user: assigned_by,
      assigned_at: Time.current,
      last_seen_at: Time.current
    )

    cookies.permanent[ShelfStack::WORKSTATION_COOKIE_NAME] = {
      value: raw_token,
      httponly: true,
      same_site: :lax
    }

    AuditEvents.record!(
      actor: assigned_by,
      event_name: "workstation_assignment.created",
      auditable: assignment,
      details: { workstation_id: workstation.id, store_id: workstation.store_id }
    )

    assignment
  end

  def self.revoke!(assignment:, actor:)
    assignment.revoke!
    AuditEvents.record!(
      actor: actor,
      event_name: "workstation_assignment.revoked",
      auditable: assignment
    )
  end

  def self.reassign!(workstation:, assigned_by:, cookies:)
    old = resolve_from_cookie(cookies)
    if old
      old.revoke!
      AuditEvents.record!(
        actor: assigned_by,
        event_name: "workstation_assignment.reassigned",
        auditable: old,
        details: { new_workstation_id: workstation.id }
      )
    end
    assign!(workstation: workstation, assigned_by: assigned_by, cookies: cookies)
  end

  def self.revoke_active_for_workstation!(workstation)
    WorkstationAssignment.active_records.where(workstation: workstation).find_each(&:revoke!)
  end

  def self.clear_cookie(cookies)
    cookies.delete(ShelfStack::WORKSTATION_COOKIE_NAME)
  end
end
