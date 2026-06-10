# frozen_string_literal: true

class Authorization
  def self.allowed?(user:, permission_key:, store: Current.store)
    new(user: user, permission_key: permission_key, store: store).allowed?
  end

  def initialize(user:, permission_key:, store: Current.store)
    @user = user
    @permission_key = permission_key
    @store = store
  end

  def allowed?
    return false if user.blank?
    return false if user.system_user?
    return false unless user.active?
    return false if permission.blank? || !permission.active?

    active_assignments.any? do |assignment|
      next false unless assignment.role.active?
      next false unless assignment.role.permissions.any? { |p| p.id == permission.id }

      if assignment.global_scoped?
        true
      elsif assignment.store_scoped?
        store.present? && assignment.store_id == store.id
      else
        false
      end
    end
  end

  def self.super_administrator_count
    UserRoleAssignment.active_records.global_scope
                      .joins(:role)
                      .where(roles: { role_key: ShelfStack::SUPER_ADMINISTRATOR_ROLE_KEY, active: true })
                      .count
  end

  def self.can_remove_super_admin?(assignment)
    return true unless assignment.role.role_key == ShelfStack::SUPER_ADMINISTRATOR_ROLE_KEY
    return true unless assignment.global_scoped?
    return true unless assignment.active?

    super_administrator_count > 1
  end

  private

  attr_reader :user, :permission_key, :store

  def permission
    @permission ||= Permission.find_by(permission_key: permission_key)
  end

  def active_assignments
    user.user_role_assignments.active_records.includes(role: :permissions)
  end
end
