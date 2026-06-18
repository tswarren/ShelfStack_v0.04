# frozen_string_literal: true

module NestedLineNumberUniqueness
  extend ActiveSupport::Concern

  class_methods do
    def validates_nested_line_number_uniqueness(parent_association_name, foreign_key:)
      @nested_line_parent_association = parent_association_name
      @nested_line_foreign_key = foreign_key

      validate :line_number_unique_within_parent_lines, unless: :marked_for_destruction?
    end

    def nested_line_parent_association
      @nested_line_parent_association
    end

    def nested_line_foreign_key
      @nested_line_foreign_key
    end
  end

  private

  def line_number_unique_within_parent_lines
    return if line_number.blank?

    parent = public_send(self.class.nested_line_parent_association)
    return if parent.blank?

    parent_lines = in_memory_parent_lines(parent)

    if parent_lines.any? do |sibling|
      sibling != self && !sibling.marked_for_destruction? && sibling.line_number == line_number
    end
      errors.add(:line_number, :taken)
      return
    end

    excluded_ids = parent_lines.filter_map(&:id)
    scope = self.class.where(self.class.nested_line_foreign_key => public_send(self.class.nested_line_foreign_key),
                             line_number: line_number)
    scope = scope.where.not(id: excluded_ids) if excluded_ids.any?

    errors.add(:line_number, :taken) if scope.exists?
  end

  def in_memory_parent_lines(parent)
    association = parent.association(self.class.model_name.collection.to_sym)
    association.loaded? ? association.target : association.load_target
  end
end
