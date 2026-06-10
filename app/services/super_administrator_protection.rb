# frozen_string_literal: true

class SuperAdministratorProtection
  class Error < StandardError; end

  def self.super_administrator_role
    Role.find_by(role_key: ShelfStack::SUPER_ADMINISTRATOR_ROLE_KEY)
  end

  def self.protected_role?(role)
    role.role_key == ShelfStack::SUPER_ADMINISTRATOR_ROLE_KEY && role.system_role?
  end

  def self.ensure_role_inactivatable!(role)
    return unless protected_role?(role)

    raise Error, "The Super Administrator role cannot be inactivated."
  end

  def self.ensure_permission_granted!(role, permission)
    return unless protected_role?(role)

    raise Error, "Permissions cannot be removed from the Super Administrator role."
  end

  def self.ensure_user_mutable!(user)
    return unless user.system_user?

    raise Error, "The system user cannot be modified through setup."
  end

  def self.ensure_assignment_removable!(assignment)
    return unless assignment.active?
    return unless assignment.global_scoped?
    return unless assignment.role.role_key == ShelfStack::SUPER_ADMINISTRATOR_ROLE_KEY

    remaining = UserRoleAssignment.active_records.global_scope
      .joins(:role)
      .where(roles: { role_key: ShelfStack::SUPER_ADMINISTRATOR_ROLE_KEY })
      .where.not(id: assignment.id)
      .exists?

    return if remaining

    raise Error, "Cannot remove the last active super administrator assignment."
  end

  def self.restore!
    role = super_administrator_role
    return unless role

    role.update!(active: true, system_role: true)
    Permission.active_records.find_each { |permission| role.grant_permission!(permission) }

    admin = User.find_by(username: "admin")
    return unless admin

    UserRoleAssignment.find_or_initialize_by(
      user: admin,
      role: role,
      scope_type: "global"
    ).tap do |assignment|
      assignment.active = true
      assignment.assigned_at ||= Time.current
      assignment.save!
    end
  end
end
