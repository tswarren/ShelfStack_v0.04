# frozen_string_literal: true

class ExternalDataSource < ApplicationRecord
  HEALTH_CHECK_STATUSES = %w[ok failed unknown].freeze

  has_many :external_lookup_requests, dependent: :restrict_with_error
  has_many :external_catalog_imports, dependent: :restrict_with_error

  validates :source_key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :base_url, presence: true
  validates :last_health_check_status, inclusion: { in: HEALTH_CHECK_STATUSES }, allow_blank: true

  scope :active_records, -> { where(active: true) }

  def health_check_fresh?(max_age: 30.minutes)
    last_health_check_at.present? && last_health_check_at >= max_age.ago
  end
end
