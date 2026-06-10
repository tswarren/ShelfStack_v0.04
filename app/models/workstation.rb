# frozen_string_literal: true

class Workstation < ApplicationRecord
  WORKSTATION_TYPES = %w[register service_desk back_office receiving].freeze

  belongs_to :store
  has_many :workstation_assignments, dependent: :restrict_with_error
  has_many :user_sessions, dependent: :restrict_with_error

  validates :workstation_type, inclusion: { in: WORKSTATION_TYPES }
  validates :workstation_number, presence: true, length: { maximum: 3 }
  validates :workstation_code, :name, presence: true
  validates :workstation_number, uniqueness: { scope: :store_id }
  validates :workstation_code, uniqueness: { scope: :store_id }

  before_validation :normalize_workstation_number

  scope :active_records, -> { where(active: true) }

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  private

  def normalize_workstation_number
    return if workstation_number.blank?

    self.workstation_number = workstation_number.to_s.rjust(3, "0")
  end
end
