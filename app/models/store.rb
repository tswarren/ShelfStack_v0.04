# frozen_string_literal: true

class Store < ApplicationRecord
  has_many :workstations, dependent: :restrict_with_error
  has_many :user_role_assignments, dependent: :restrict_with_error
  has_many :user_sessions, dependent: :restrict_with_error
  has_many :users, foreign_key: :default_store_id, dependent: :nullify, inverse_of: :default_store

  validates :store_number, presence: true, uniqueness: true, length: { maximum: 4 }
  validates :name, presence: true, length: { maximum: 80 }
  validates :country_code, presence: true, length: { is: 2 }
  validates :time_zone, presence: true

  before_validation :normalize_email

  scope :active_records, -> { where(active: true) }

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  private

  def normalize_email
    self.email = email&.downcase&.strip
  end
end
