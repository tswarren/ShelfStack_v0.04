# frozen_string_literal: true

class PosDiscountApplication < ApplicationRecord
  SCOPES = %w[line transaction].freeze
  SOURCES = %w[manual system promotion legacy].freeze
  DISCOUNT_METHODS = %w[amount percent price_override].freeze

  belongs_to :pos_transaction
  belongs_to :pos_transaction_line, optional: true
  belongs_to :discount_reason
  belongs_to :pos_authorization, optional: true
  belongs_to :applied_by_user, class_name: "User"
  belongs_to :approved_by_user, class_name: "User", optional: true
  belongs_to :voided_by_user, class_name: "User", optional: true

  has_many :pos_discount_allocations, dependent: :destroy

  validates :scope, presence: true, inclusion: { in: SCOPES }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :discount_method, presence: true, inclusion: { in: DISCOUNT_METHODS }
  validates :stack_order, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :applied_at, presence: true
  validates :base_amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :calculated_discount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :applied_discount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :entered_percent_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validate :line_scope_requires_line
  validate :method_specific_fields
  validate :cannot_change_when_transaction_locked, on: :update

  scope :active_records, -> { where(voided_at: nil) }

  def active?
    voided_at.blank?
  end

  def voided?
    voided_at.present?
  end

  def line_scope?
    scope == "line"
  end

  def transaction_scope?
    scope == "transaction"
  end

  private

  def line_scope_requires_line
    return unless line_scope?
    return if pos_transaction_line_id.present?

    errors.add(:pos_transaction_line, "must be present for line-scope discounts")
  end

  def method_specific_fields
    case discount_method
    when "amount"
      errors.add(:entered_amount_cents, "must be present for amount discounts") if entered_amount_cents.blank?
    when "percent"
      errors.add(:entered_percent_bps, "must be present for percent discounts") if entered_percent_bps.blank?
    when "price_override"
      errors.add(:target_price_cents, "must be present for price override discounts") if target_price_cents.blank?
    end
  end

  def cannot_change_when_transaction_locked
    return if pos_transaction.blank? || pos_transaction.editable?

    errors.add(:base, "cannot modify discount applications on a locked transaction")
  end
end
