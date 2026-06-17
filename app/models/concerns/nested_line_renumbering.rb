# frozen_string_literal: true

module NestedLineRenumbering
  extend ActiveSupport::Concern

  private

  def renumber_nested_lines(lines)
    lines.reject { |line| line.marked_for_destruction? || line.destroyed? }.each_with_index do |line, index|
      line.line_number = index + 1
    end
  end
end
