# frozen_string_literal: true

class UserRoleAssignmentService
  class Error < StandardError; end

  def self.assign!(user:, role:, scope_type:, store: nil, assigned_by: nil)
    raise Error, "System user cannot be assigned roles." if user.system_user?
    raise Error, "Role is inactive." unless role.active?
    raise Error, "Invalid scope type." unless UserRoleAssignment::SCOPE_TYPES.include?(scope_type)
    raise Error, "Store is required for store-scoped assignments." if scope_type == "store" && store.blank?
    raise Error, "Store must be omitted for global assignments." if scope_type == "global" && store.present?
    raise Error, "Store is inactive." if store.present? && !store.active?

    existing = find_existing(user:, role:, scope_type:, store:)

    if existing&.active?
      raise Error, "This role assignment already exists."
    end

    if existing
      existing.assign_attributes(
        active: true,
        assigned_by_user: assigned_by,
        assigned_at: Time.current
      )
      existing.save!
      existing
    else
      UserRoleAssignment.create!(
        user: user,
        role: role,
        scope_type: scope_type,
        store: store,
        assigned_by_user: assigned_by,
        assigned_at: Time.current,
        active: true
      )
    end
  end

  def self.remove!(assignment:)
    raise Error, "Role assignment is already inactive." unless assignment.active?

    SuperAdministratorProtection.ensure_assignment_removable!(assignment)
    assignment.inactivate!
    assignment
  end

  def self.find_existing(user:, role:, scope_type:, store:)
    if scope_type == "global"
      UserRoleAssignment.find_by(user: user, role: role, scope_type: "global")
    else
      UserRoleAssignment.find_by(user: user, role: role, scope_type: "store", store: store)
    end
  end
  private_class_method :find_existing
end
