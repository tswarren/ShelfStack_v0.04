# frozen_string_literal: true

class Customer < ApplicationRecord
  PREFERRED_CONTACT_METHODS = %w[phone email sms in_person other].freeze

  belongs_to :home_store, class_name: "Store", optional: true

  has_many :customer_requests, dependent: :restrict_with_error
  has_many :special_orders, dependent: :restrict_with_error
  has_many :inventory_reservations, dependent: :restrict_with_error
  has_many :customer_contact_events, dependent: :restrict_with_error

  validates :display_name, presence: true
  validates :preferred_contact_method, inclusion: { in: PREFERRED_CONTACT_METHODS }, allow_blank: true

  scope :active_records, -> { where(active: true) }

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end
end
