# frozen_string_literal: true

class DisplayLocation < ApplicationRecord
  belongs_to :parent, class_name: "DisplayLocation", optional: true
  has_many :children, class_name: "DisplayLocation", foreign_key: :parent_id, dependent: :restrict_with_error,
           inverse_of: :parent
  has_many :store_display_locations, dependent: :restrict_with_error
  has_many :products, foreign_key: :default_display_location_id, dependent: :restrict_with_error,
           inverse_of: :default_display_location
  has_many :product_variants, dependent: :restrict_with_error

  validates :name, presence: true
  validates :short_name, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :sort_order, numericality: { only_integer: true }
  validate :parent_must_be_active

  scope :active_records, -> { where(active: true) }

  def self.active_for_tree_select
    active_records.order(:sort_order, :short_name, :name).to_a
  end

  def self.ordered_tree_rows
    TreeOrdering.rows(order(:sort_order, :short_name, :name).to_a)
  end

  before_validation :normalize_strings

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  def ancestor_chain
    chain = []
    current = self
    seen_ids = {}

    while current && seen_ids[current.id].nil?
      seen_ids[current.id] = true
      chain.unshift(current)
      current = current.parent
    end

    chain
  end

  private

  def normalize_strings
    self.name = name&.strip
    self.short_name = short_name&.strip
  end

  def parent_must_be_active
    return if parent.blank? || parent.active?

    errors.add(:parent, "must be active")
  end
end
