# frozen_string_literal: true

class SourcingAttempt < ApplicationRecord
  STATUSES = %w[
    pending
    submitted
    confirmed
    partially_confirmed
    backordered
    canceled
    failed
    cascaded
  ].freeze

  IN_FLIGHT_STATUSES = %w[pending submitted].freeze
  SOURCE_LEVELS = %w[variant_vendor product_vendor variant_preferred product_preferred manual].freeze

  belongs_to :store
  belongs_to :sourcing_run
  belongs_to :demand_line
  belongs_to :product
  belongs_to :product_variant
  belongs_to :vendor
  belongs_to :product_variant_vendor, optional: true
  belongs_to :product_vendor, optional: true
  belongs_to :purchase_order_line, optional: true
  belongs_to :previous_sourcing_attempt, class_name: "SourcingAttempt", optional: true
  belongs_to :submitted_by_user, class_name: "User", optional: true
  belongs_to :override_authorized_by_user, class_name: "User", optional: true
  belongs_to :canceled_by_user, class_name: "User", optional: true

  has_many :vendor_responses, dependent: :restrict_with_error
  has_many :demand_allocations, dependent: :restrict_with_error

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :sequence_number, numericality: { only_integer: true, greater_than: 0 }
  validates :quantity_requested, numericality: { only_integer: true, greater_than: 0 }
  validate :demand_line_consistency
  validate :manual_override_fields
  validate :submitted_fields_when_submitted

  scope :in_flight, -> { where(status: IN_FLIGHT_STATUSES) }

  def in_flight?
    IN_FLIGHT_STATUSES.include?(status)
  end

  def pending?
    status == "pending"
  end

  private

  def demand_line_consistency
    return if demand_line.blank?

    if store_id.present? && demand_line.store_id != store_id
      errors.add(:store, "must match demand line store")
    end

    if product_variant_id.present? && demand_line.product_variant_id != product_variant_id
      errors.add(:product_variant, "must match demand line variant")
    end
  end

  def manual_override_fields
    return unless manual_vendor_override?

    errors.add(:manual_override_reason, "is required") if manual_override_reason.blank?
    errors.add(:override_authorized_by_user, "is required") if override_authorized_by_user_id.blank?
    errors.add(:override_authorized_at, "is required") if override_authorized_at.blank?
  end

  def submitted_fields_when_submitted
    return unless status == "submitted" || submitted_at.present?

    errors.add(:submitted_by_user, "is required when submitted") if submitted_by_user_id.blank? && status == "submitted"
    errors.add(:submitted_at, "is required when submitted") if submitted_at.blank? && status == "submitted"
  end
end
