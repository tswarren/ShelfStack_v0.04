# frozen_string_literal: true

class SessionLifecycle
  class Error < StandardError; end

  def self.login(user:, workstation_assignment:, request:, cookies:, allow_missing_workstation: false)
    raise Error, "User cannot log in" unless user.interactive?
    raise Error, "User is locked out" if user.locked_out?
    raise Error, "Workstation assignment required" if workstation_assignment.nil? && !allow_missing_workstation

    user.record_successful_login!

    raw_token = TokenDigest.generate
    session = UserSession.create!(
      user: user,
      store: workstation_assignment&.workstation&.store,
      workstation: workstation_assignment&.workstation,
      session_token_digest: TokenDigest.digest(raw_token),
      status: "active",
      last_activity_at: Time.current,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    cookies.permanent[ShelfStack::SESSION_COOKIE_NAME] = {
      value: raw_token,
      httponly: true,
      same_site: :lax
    }

    set_current_context(session, workstation_assignment)

    AuditEvents.record!(
      actor: user,
      event_name: "user.login",
      auditable: user,
      details: { user_session_id: session.id }
    )

    session
  end

  def self.resolve_from_cookie(cookies)
    raw_token = cookies[ShelfStack::SESSION_COOKIE_NAME]
    return nil if raw_token.blank?

    session = UserSession.find_by(session_token_digest: TokenDigest.digest(raw_token))
    return nil unless session
    return nil if session.terminal?

    session
  end

  def self.load_context!(cookies:, workstation_assignment: nil)
    session = resolve_from_cookie(cookies)
    return nil unless session

    assignment = workstation_assignment || WorkstationAssignmentService.resolve_from_cookie(cookies)
    set_current_context(session, assignment)
    check_inactivity!(session)
    session
  end

  def self.logout(session:, actor:, cookies:)
    session.end!(ended_by: actor)
    AuditEvents.record!(actor: actor, event_name: "user.logout", auditable: session.user)
    clear_session_cookie(cookies)
    reset_current_context
  end

  def self.lock!(session:, actor:)
    session.lock!
    AuditEvents.record!(actor: actor, event_name: "session.locked", auditable: session)
  end

  def self.unlock!(session:, user:, pin:)
    raise Error, "Invalid PIN" unless user.authenticate_pin(pin)

    session.unlock!
    AuditEvents.record!(actor: user, event_name: "session.unlocked", auditable: session)
  end

  def self.force_end!(session:, actor:)
    session.force_end!(ended_by: actor)
    AuditEvents.record!(actor: actor, event_name: "session.force_ended", auditable: session)
  end

  def self.check_inactivity!(session)
    return unless session.active?
    return unless session.last_activity_at < ShelfStack::SESSION_INACTIVITY_TIMEOUT.ago

    session.expire!
    AuditEvents.record!(
      actor: User.find_by!(username: ShelfStack::SYSTEM_USERNAME),
      event_name: "session.expired",
      auditable: session
    )
  end

  def self.touch_activity!(session)
    session.touch_activity! if session.active?
  end

  def self.clear_session_cookie(cookies)
    cookies.delete(ShelfStack::SESSION_COOKIE_NAME)
  end

  def self.set_current_context(session, workstation_assignment)
    Current.user = session.user
    Current.user_session = session
    Current.workstation_assignment = workstation_assignment
    Current.workstation = workstation_assignment&.workstation
    Current.store = workstation_assignment&.workstation&.store || session.store
    Current.time_zone = Current.store&.time_zone
  end

  def self.reset_current_context
    Current.reset
  end
end
