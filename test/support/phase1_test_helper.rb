# frozen_string_literal: true

require "ostruct"

module Phase1TestHelper
  def seed_minimal_permissions!
    Seeds::Phase1Permissions.seed!
    Seeds::Phase2Permissions.seed!
    Seeds::Phase3Permissions.seed!
    Seeds::Phase3bPermissions.seed!
    Seeds::Phase4Permissions.seed!
    Seeds::Phase5Permissions.seed!
    Seeds::Phase6Permissions.seed!
    Seeds::Phase65Permissions.seed!
    Seeds::Phase7aPermissions.seed!
    Seeds::Phase7bPermissions.seed!
    Seeds::Phase852Permissions.seed!
  end

  def create_store!(attrs = {})
    Store.create!({
      store_number: unique_store_number,
      name: "Test Store",
      country_code: "US",
      time_zone: "America/New_York",
      active: true
    }.merge(attrs))
  end

  def unique_store_number
    loop do
      number = format("%04x", SecureRandom.random_number(65_536))
      return number unless Store.exists?(store_number: number)
    end
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
    pin_provided = attrs.key?(:pin)
    pin = attrs.delete(:pin) if pin_provided

    user = User.create!({
      user_type: "user",
      username: "testuser",
      first_name: "Test",
      last_name: "User",
      display_name: "Test User",
      password: "Password123!",
      interactive_login_enabled: true,
      active: true
    }.merge(attrs))

    if pin_provided && pin.present?
      user.pin = pin
      user.save!
    elsif !pin_provided
      user.pin = "1234"
      user.save!
    end

    user
  end

  def grant_permission!(user, permission_key, store: nil)
    permission = Permission.find_by!(permission_key: permission_key)
    role = Role.find_or_create_by!(role_key: "test_#{permission_key.tr('.', '_')}") do |r|
      r.name = "Test #{permission_key}"
      r.active = true
    end
    role.grant_permission!(permission)

    assignment = UserRoleAssignment.find_or_initialize_by(
      user: user,
      role: role,
      scope_type: store ? "store" : "global",
      store: store
    )
    assignment.active = true
    assignment.save!
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

  def login_user!(user, workstation:, password: "Password123!")
    assign_workstation!(workstation, cookies)
    post login_path, params: { username: user.username, password: password }
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
