# frozen_string_literal: true

class ExternalLookupRequest < ApplicationRecord
  LOOKUP_TYPES = %w[isbn keyword advanced key_check bulk feed].freeze
  STATUSES = %w[pending completed not_found failed rate_limited cancelled].freeze

  belongs_to :external_data_source
  belongs_to :requested_by_user, class_name: "User"
  has_one :external_lookup_result, dependent: :destroy

  validates :lookup_type, presence: true, inclusion: { in: LOOKUP_TYPES }
  validates :query, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
end
