# frozen_string_literal: true

class UserRoleAssignment < ApplicationRecord
  SCOPE_TYPES = %w[global store].freeze

  belongs_to :user
  belongs_to :role
  belongs_to :store, optional: true
  belongs_to :assigned_by_user, class_name: "User", optional: true

  validates :scope_type, inclusion: { in: SCOPE_TYPES }
  validates :store, presence: true, if: :store_scoped?
  validates :store, absence: true, if: :global_scoped?
  validate :prevent_last_super_admin_removal, on: :update, if: -> { active_changed? && !active? }

  scope :active_records, -> { where(active: true) }
  scope :global_scope, -> { where(scope_type: "global") }
  scope :store_scope, -> { where(scope_type: "store") }

  def global_scoped?
    scope_type == "global"
  end

  def store_scoped?
    scope_type == "store"
  end

  def inactivate!
    update!(active: false)
  end

  private

  def prevent_last_super_admin_removal
    return unless role.role_key == ShelfStack::SUPER_ADMINISTRATOR_ROLE_KEY && global_scoped?

    remaining = self.class.active_records.global_scope
                    .joins(:role)
                    .where(roles: { role_key: ShelfStack::SUPER_ADMINISTRATOR_ROLE_KEY })
                    .where.not(id: id)
                    .exists?
    errors.add(:base, "Cannot remove the last active super administrator assignment") unless remaining
  end
end
