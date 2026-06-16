# frozen_string_literal: true

class InventoryAdjustment < ApplicationRecord
  ADJUSTMENT_TYPES = %w[opening_inventory manual_adjustment balance_correction].freeze
  STATUSES = %w[draft posted cancelled].freeze

  belongs_to :store
  belongs_to :posted_by_user, class_name: "User", optional: true
  belongs_to :inventory_posting, optional: true

  has_many :inventory_adjustment_lines, -> { order(:line_number) }, dependent: :destroy, inverse_of: :inventory_adjustment

  accepts_nested_attributes_for :inventory_adjustment_lines, allow_destroy: true, reject_if: :all_blank

  before_validation :normalize_line_numbers

  validates :adjustment_type, presence: true, inclusion: { in: ADJUSTMENT_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :store_must_be_active
  validate :posted_fields_locked_when_posted, on: :update
  validate :cannot_edit_when_posted, on: :update

  scope :active_drafts, -> { where(status: "draft") }
  scope :posted_records, -> { where(status: "posted") }

  def draft?
    status == "draft"
  end

  def posted?
    status == "posted"
  end

  def cancelled?
    status == "cancelled"
  end

  def cancel!
    raise ActiveRecord::RecordInvalid, self unless draft?

    update!(status: "cancelled")
  end

  private

  def store_must_be_active
    return if store.blank? || store.active?

    errors.add(:store, "must be active")
  end

  def posted_fields_locked_when_posted
    return unless status_in_database == "posted"

    errors.add(:base, "cannot modify a posted adjustment") if changed?
  end

  def cannot_edit_when_posted
    return unless status_in_database == "posted"

    errors.add(:base, "posted adjustments are immutable")
  end

  def normalize_line_numbers
    return if posted?

    inventory_adjustment_lines.reject(&:marked_for_destruction?).each_with_index do |line, index|
      line.line_number = index + 1
    end
  end
end
