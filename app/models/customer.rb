# frozen_string_literal: true

class Customer < ApplicationRecord
  PREFERRED_CONTACT_METHODS = %w[phone email sms in_person other].freeze
  SOURCES = %w[manual buyback_intake].freeze

  belongs_to :home_store, class_name: "Store", optional: true
  belongs_to :created_by_user, class_name: "User", optional: true
  belongs_to :updated_by_user, class_name: "User", optional: true
  belongs_to :merged_into_customer, class_name: "Customer", optional: true

  has_many :customer_requests, dependent: :restrict_with_error
  has_many :demand_lines, dependent: :restrict_with_error
  has_many :special_orders, dependent: :restrict_with_error
  has_many :inventory_reservations, dependent: :restrict_with_error
  has_many :customer_contact_events, dependent: :restrict_with_error
  has_many :buyback_sessions, dependent: :restrict_with_error

  validates :display_name, presence: true
  validates :country_code, presence: true, length: { is: 2 }
  validates :preferred_contact_method, inclusion: { in: PREFERRED_CONTACT_METHODS }, allow_blank: true

  before_validation :sync_display_name_from_names
  before_save :normalize_contact_fields

  scope :active_records, -> { where(active: true) }

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  def seller_identity_complete?
    first_name.present? && last_name.present? && address_line1.present? &&
      city.present? && region_code.present? && postal_code.present?
  end

  private

  def sync_display_name_from_names
    return if display_name.present?
    return if first_name.blank? && last_name.blank?

    self.display_name = [ first_name, last_name ].compact_blank.join(" ")
  end

  def normalize_contact_fields
    self.phone_normalized = phone&.gsub(/\D/, "").presence
    self.email_normalized = email&.strip&.downcase.presence
  end
end
