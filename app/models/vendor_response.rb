# frozen_string_literal: true

class VendorResponse < ApplicationRecord
  RESPONSE_STATUSES = %w[
    confirmed
    partially_confirmed
    backordered
    unavailable
    canceled
    failed
    substitute_offered
    mixed
  ].freeze

  RESPONSE_METHODS = %w[manual import api].freeze

  QUANTITY_FIELDS = %i[
    quantity_confirmed
    quantity_backordered
    quantity_unavailable
    quantity_canceled
    quantity_failed
    quantity_substitute_offered
  ].freeze

  belongs_to :store
  belongs_to :sourcing_attempt
  belongs_to :vendor
  belongs_to :responded_by_user, class_name: "User"
  belongs_to :purchase_order_line, optional: true

  has_many :demand_allocations, dependent: :restrict_with_error

  validates :response_status, presence: true, inclusion: { in: RESPONSE_STATUSES }
  validates :response_method, presence: true, inclusion: { in: RESPONSE_METHODS }
  validates :responded_at, presence: true
  validates(*QUANTITY_FIELDS, numericality: { only_integer: true, greater_than_or_equal_to: 0 })
  validate :quantity_sum_within_attempt
  validate :final_response_quantity_sum

  def quantity_total
    QUANTITY_FIELDS.sum { |field| public_send(field).to_i }
  end

  private

  def quantity_sum_within_attempt
    return if sourcing_attempt.blank?

    if quantity_total > sourcing_attempt.quantity_requested
      errors.add(:base, "response quantity total exceeds attempt quantity requested")
    end
  end

  def final_response_quantity_sum
    return unless final_response?
    return if sourcing_attempt.blank?

    if quantity_total != sourcing_attempt.quantity_requested
      errors.add(:base, "final response quantity total must equal attempt quantity requested")
    end
  end
end
