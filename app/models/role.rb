# frozen_string_literal: true

class Role < ApplicationRecord
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions
  has_many :user_role_assignments, dependent: :restrict_with_error
  has_many :users, through: :user_role_assignments

  validates :role_key, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active_records, -> { where(active: true) }

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  def grant_permission!(permission)
    permissions << permission unless permissions.include?(permission)
  end

  def revoke_permission!(permission)
    role_permissions.find_by(permission: permission)&.destroy
  end
end
