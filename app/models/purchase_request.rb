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

  BUILDABLE_LINE_STATUSES = %w[open sourcing_needed ready_to_order partially_ordered].freeze
  CLOSED_STATUSES = %w[cancelled closed].freeze

  def buildable_lines
    purchase_request_lines.select { |line| BUILDABLE_LINE_STATUSES.include?(line.status) }
  end

  def buildable?
    CLOSED_STATUSES.exclude?(status) && buildable_lines.any?
  end

  def refresh_status_from_lines!
    lines = purchase_request_lines.reload
    return if lines.empty?

    if lines.all? { |line| line.status == "added_to_po" }
      update!(status: "added_to_po") unless status == "added_to_po"
    elsif lines.any? { |line| %w[added_to_po partially_ordered].include?(line.status) }
      update!(status: "partially_ordered") unless status == "partially_ordered"
    end
  end

  def self.refresh_statuses_for_lines!(lines)
    Array(lines).filter_map(&:purchase_request_id).uniq.each do |request_id|
      find(request_id).refresh_status_from_lines!
    end
  end

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
