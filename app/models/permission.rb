# frozen_string_literal: true

class Permission < ApplicationRecord
  has_many :role_permissions, dependent: :restrict_with_error
  has_many :roles, through: :role_permissions

  validates :permission_key, presence: true, uniqueness: true
  validates :permission_group, :name, presence: true

  scope :active_records, -> { where(active: true) }
end
