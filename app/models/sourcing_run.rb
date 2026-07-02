# frozen_string_literal: true

class SourcingRun < ApplicationRecord
  STATUSES = %w[open partially_resolved resolved needs_review canceled].freeze
  ACTIVE_STATUSES = %w[open partially_resolved needs_review].freeze
  TERMINAL_STATUSES = %w[resolved canceled].freeze

  belongs_to :store
  belongs_to :demand_line
  belongs_to :product
  belongs_to :product_variant
  belongs_to :started_by_user, class_name: "User"
  belongs_to :closed_by_user, class_name: "User", optional: true
  belongs_to :canceled_by_user, class_name: "User", optional: true

  has_many :sourcing_attempts, dependent: :restrict_with_error

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :quantity_requested, numericality: { only_integer: true, greater_than: 0 }
  validates :started_at, presence: true
  validate :demand_line_consistency
  validate :at_most_one_active_run_per_demand_line, on: :create

  scope :active_runs, -> { where(status: ACTIVE_STATUSES) }

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def terminal?
    TERMINAL_STATUSES.include?(status)
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

    if product_id.present? && demand_line.product_id.present? && demand_line.product_id != product_id
      errors.add(:product_id, "must match demand line product")
    end
  end

  def at_most_one_active_run_per_demand_line
    return if demand_line_id.blank?
    return unless ACTIVE_STATUSES.include?(status)

    if SourcingRun.active_runs.where(demand_line_id: demand_line_id).where.not(id: id).exists?
      errors.add(:demand_line, "already has an active sourcing run")
    end
  end
end
