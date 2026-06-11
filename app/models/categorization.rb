# frozen_string_literal: true

class Categorization < ApplicationRecord
  SOURCES = %w[manual bisac import template].freeze

  belongs_to :category_node
  belongs_to :categorizable, polymorphic: true

  validates :source, inclusion: { in: SOURCES }, allow_blank: true
  validate :category_node_must_be_active
  validate :only_one_primary_per_scheme

  scope :primary_records, -> { where(primary: true) }

  private

  def category_node_must_be_active
    return if category_node.blank? || category_node.active?

    errors.add(:category_node, "must be active")
  end

  def only_one_primary_per_scheme
    return unless primary?

    scope = self.class.where(
      categorizable_type: categorizable_type,
      categorizable_id: categorizable_id,
      primary: true
    ).joins(:category_node).where(category_nodes: { category_scheme_id: category_node.category_scheme_id })
    scope = scope.where.not(id: id) if persisted?

    return unless scope.exists?

    errors.add(:primary, "already assigned for this scheme")
  end
end
