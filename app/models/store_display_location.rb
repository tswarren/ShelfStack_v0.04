# frozen_string_literal: true

class StoreDisplayLocation < ApplicationRecord
  belongs_to :display_location
  belongs_to :store

  validates :linear_feet, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :display_location_id, uniqueness: { scope: :store_id }
  validate :display_location_must_be_active
  validate :store_must_be_active

  scope :active_records, -> { where(active: true) }

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  private

  def display_location_must_be_active
    return if display_location.blank? || display_location.active?

    errors.add(:display_location, "must be active")
  end

  def store_must_be_active
    return if store.blank? || store.active?

    errors.add(:store, "must be active")
  end
end
