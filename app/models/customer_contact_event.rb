# frozen_string_literal: true

class CustomerContactEvent < ApplicationRecord
  CONTACT_METHODS = %w[phone email sms in_person other].freeze
  DIRECTIONS = %w[outbound inbound].freeze
  STATUSES = %w[attempted reached left_message no_answer failed not_needed].freeze

  belongs_to :customer, optional: true
  belongs_to :customer_request, optional: true
  belongs_to :customer_request_line, optional: true
  belongs_to :recorded_by_user, class_name: "User"

  validates :contact_method, presence: true, inclusion: { in: CONTACT_METHODS }
  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :summary, presence: true
  validates :occurred_at, presence: true
  validate :context_present

  private

  def context_present
    return if customer_id.present? || customer_request_id.present?

    errors.add(:base, "Customer or customer request is required")
  end
end
