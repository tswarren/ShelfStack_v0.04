# frozen_string_literal: true

class Department < ApplicationRecord
  include DepartmentNumberNormalizer

  has_many :sub_departments, dependent: :restrict_with_error

  validates :department_number, presence: true, uniqueness: true, length: { is: 3 },
            format: { with: /\A[0-9]{3}\z/, message: "must be three numeric digits" }
  validates :name, presence: true, uniqueness: true
  validates :short_name, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :gl_account_code, length: { maximum: 20 }, allow_blank: true

  scope :active_records, -> { where(active: true) }

  before_validation :normalize_strings

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  private

  def normalize_strings
    self.name = name&.strip
    self.short_name = short_name&.strip
    self.gl_account_code = gl_account_code&.strip.presence
  end
end
