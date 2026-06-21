# frozen_string_literal: true

class InventoryReservation < ApplicationRecord
  RESERVATION_TYPES = %w[on_hand_hold incoming_reserve special_order_reserve].freeze

  STATUSES = %w[active ready fulfilled released expired cancelled].freeze

  RELEASE_REASONS = %w[
    customer_declined customer_no_show staff_release expired converted_to_sale
    cancelled_request po_cancelled receipt_short other
  ].freeze

  ON_HAND_CACHE_STATUSES = %w[active ready].freeze
  ON_HAND_CACHE_TYPES = %w[on_hand_hold special_order_reserve].freeze

  belongs_to :store
  belongs_to :customer, optional: true
  belongs_to :customer_request_line, optional: true
  belongs_to :special_order, optional: true
  belongs_to :product_variant
  belongs_to :purchase_order_line, optional: true
  belongs_to :receipt_line, optional: true
  belongs_to :pos_transaction_line, optional: true
  belongs_to :reserved_by_user, class_name: "User"
  belongs_to :override_authorized_by_user, class_name: "User", optional: true

  validates :reservation_type, presence: true, inclusion: { in: RESERVATION_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :quantity_reserved, numericality: { only_integer: true, greater_than: 0 }
  validates :quantity_fulfilled, :quantity_released,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :release_reason, inclusion: { in: RELEASE_REASONS }, allow_blank: true
  validate :quantity_balance_valid
  validate :store_consistency

  scope :active_on_hand, lambda {
    where(reservation_type: ON_HAND_CACHE_TYPES, status: ON_HAND_CACHE_STATUSES)
  }

  scope :active_incoming, lambda {
    where(reservation_type: "incoming_reserve", status: "active")
  }

  def remaining_quantity
    quantity_reserved - quantity_fulfilled - quantity_released
  end

  def counts_toward_on_hand_reserved?
    ON_HAND_CACHE_TYPES.include?(reservation_type) && ON_HAND_CACHE_STATUSES.include?(status)
  end

  private

  def quantity_balance_valid
    return if quantity_fulfilled + quantity_released <= quantity_reserved

    errors.add(:base, "fulfilled and released quantities cannot exceed reserved quantity")
  end

  def store_consistency
    [
      [ customer_request_line&.customer_request&.store_id, "customer request line" ],
      [ special_order&.store_id, "special order" ]
    ].each do |other_store_id, label|
      next if other_store_id.blank? || store_id.blank?
      next if other_store_id == store_id

      errors.add(:store, "must match #{label} store")
    end
  end
end
