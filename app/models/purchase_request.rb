# frozen_string_literal: true

class PurchaseRequest < ApplicationRecord
  include NestedLineRenumbering

  STATUSES = %w[
    open sourcing_needed ready_to_order added_to_po partially_ordered cancelled closed
  ].freeze

  belongs_to :store

  has_many :purchase_request_lines, -> { order(:line_number) }, dependent: :destroy, inverse_of: :purchase_request

  accepts_nested_attributes_for :purchase_request_lines, allow_destroy: true, reject_if: :reject_blank_purchase_request_line?

  before_validation :normalize_line_numbers

  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :store_must_be_active

  scope :open_requests, -> { where(status: %w[open sourcing_needed ready_to_order]) }

  private

  def store_must_be_active
    return if store.blank? || store.active?

    errors.add(:store, "must be active")
  end

  def reject_blank_purchase_request_line?(attributes)
    return false if ActiveModel::Type::Boolean.new.cast(attributes["_destroy"])
    return false if attributes["id"].present?

    attributes["product_variant_id"].blank?
  end

  def normalize_line_numbers
    renumber_nested_lines(purchase_request_lines)
  end
end
