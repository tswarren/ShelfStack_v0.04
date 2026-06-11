# frozen_string_literal: true

class CategoryNode < ApplicationRecord
  belongs_to :category_scheme
  belongs_to :parent, class_name: "CategoryNode", optional: true
  has_many :children, class_name: "CategoryNode", foreign_key: :parent_id, dependent: :restrict_with_error,
           inverse_of: :parent
  has_many :categorizations, dependent: :restrict_with_error
  has_many :accounting_mappings, dependent: :restrict_with_error

  validates :node_key, presence: true, uniqueness: { scope: :category_scheme_id }, length: { maximum: 30 }
  validates :name, presence: true, uniqueness: { scope: :category_scheme_id }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :parent_must_belong_to_same_scheme
  validate :parent_must_be_active

  scope :active_records, -> { where(active: true) }

  before_validation :normalize_strings

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  def breadcrumb_label
    return name if parent.blank?

    "#{parent.breadcrumb_label} → #{name}"
  end

  private

  def normalize_strings
    self.node_key = node_key&.strip&.downcase
    self.name = name&.strip
  end

  def parent_must_belong_to_same_scheme
    return if parent.blank? || parent.category_scheme_id == category_scheme_id

    errors.add(:parent, "must belong to the same scheme")
  end

  def parent_must_be_active
    return if parent.blank? || parent.active?

    errors.add(:parent, "must be active")
  end
end
