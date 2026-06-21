# frozen_string_literal: true

class CustomerRequest < ApplicationRecord
  include NestedLineRenumbering

  STATUSES = %w[
    new researching awaiting_customer_response approved_to_order ordered
    partially_filled ready_for_pickup completed cancelled unfillable
  ].freeze

  SOURCES = %w[in_store phone email web pos staff].freeze
  PREFERRED_CONTACT_METHODS = Customer::PREFERRED_CONTACT_METHODS

  belongs_to :store
  belongs_to :customer, optional: true
  belongs_to :assigned_to_user, class_name: "User", optional: true
  belongs_to :created_by_user, class_name: "User"

  has_many :customer_request_lines, -> { order(:line_number) }, dependent: :destroy, inverse_of: :customer_request
  has_many :customer_contact_events, dependent: :destroy

  accepts_nested_attributes_for :customer_request_lines, allow_destroy: true, reject_if: :reject_blank_line?

  before_validation :normalize_line_numbers
  before_validation :sync_customer_snapshots

  validates :request_number, presence: true, uniqueness: { scope: :store_id }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :preferred_contact_method, inclusion: { in: PREFERRED_CONTACT_METHODS }, allow_blank: true
  validate :customer_or_snapshot_present
  validate :store_must_be_active

  scope :open_requests, -> { where.not(status: %w[completed cancelled unfillable]) }

  def display_customer_name
    customer&.display_name || customer_name_snapshot
  end

  def refresh_status_from_lines!
    CustomerRequests::HeaderStatusResolver.call!(self)
  end

  private

  def normalize_line_numbers
    renumber_nested_lines(customer_request_lines)
  end

  def customer_or_snapshot_present
    return if customer_id.present? || customer_name_snapshot.present?

    errors.add(:base, "Customer or customer name snapshot is required")
  end

  def store_must_be_active
    return if store.blank? || store.active?

    errors.add(:store, "must be active")
  end

  def sync_customer_snapshots
    return if customer.blank?

    self.customer_name_snapshot ||= customer.display_name
    self.customer_email_snapshot ||= customer.email
    self.customer_phone_snapshot ||= customer.phone
    self.preferred_contact_method ||= customer.preferred_contact_method
  end

    def reject_blank_line?(attributes)
      return false if ActiveModel::Type::Boolean.new.cast(attributes["_destroy"])
      return false if attributes["id"].present?

      attributes["request_type"].blank? &&
        attributes["provisional_title"].blank? &&
        attributes["provisional_identifier"].blank? &&
        attributes["product_variant_id"].blank?
    end
end
