# frozen_string_literal: true

module Phase1TestHelper
  def seed_minimal_permissions!
    Seeds::Phase1Permissions.seed!
    Seeds::Phase2Permissions.seed!
  end

  def create_store!(attrs = {})
    Store.create!({
      store_number: "001",
      name: "Test Store",
      country_code: "US",
      time_zone: "America/New_York",
      active: true
    }.merge(attrs))
  end

  def create_workstation!(store: nil, attrs: {})
    store ||= create_store!
    Workstation.create!({
      store: store,
      workstation_type: "register",
      workstation_number: "001",
      workstation_code: "#{store.store_number}-REG001",
      name: "Front Register",
      active: true
    }.merge(attrs))
  end

  def create_role!(attrs = {})
    Role.create!({
      role_key: "test_role",
      name: "Test Role",
      active: true
    }.merge(attrs))
  end

  def create_user!(attrs = {})
    User.create!({
      user_type: "user",
      username: "testuser",
      first_name: "Test",
      last_name: "User",
      display_name: "Test User",
      password: "Password123!",
      interactive_login_enabled: true,
      active: true
    }.merge(attrs))
  end

  def grant_permission!(user, permission_key, store: nil)
    permission = Permission.find_by!(permission_key: permission_key)
    role = Role.find_or_create_by!(role_key: "test_#{permission_key.tr('.', '_')}") do |r|
      r.name = "Test #{permission_key}"
      r.active = true
    end
    role.grant_permission!(permission)
    UserRoleAssignment.create!(
      user: user,
      role: role,
      scope_type: store ? "store" : "global",
      store: store,
      active: true
    )
  end

  def assign_workstation!(workstation, cookies)
    WorkstationAssignment.active_records.where(workstation: workstation).find_each(&:revoke!)
    raw = TokenDigest.generate
    WorkstationAssignment.create!(
      workstation: workstation,
      assignment_token_digest: TokenDigest.digest(raw),
      assigned_at: Time.current
    )
    cookies[ShelfStack::WORKSTATION_COOKIE_NAME] = raw
  end

  def login_as(user, workstation:, cookies:)
    assign_workstation!(workstation, cookies)
    assignment = WorkstationAssignment.active_records.last
    SessionLifecycle.login(
      user: user,
      workstation_assignment: assignment,
      request: OpenStruct.new(remote_ip: "127.0.0.1", user_agent: "Test"),
      cookies: cookies
    )
  end
end
