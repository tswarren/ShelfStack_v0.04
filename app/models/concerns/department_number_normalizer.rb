# frozen_string_literal: true

module DepartmentNumberNormalizer
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_department_number
  end

  private

  def normalize_department_number
    return if department_number.blank?

    stripped = department_number.to_s.strip
    return if stripped.blank?

    unless stripped.match?(/\A\d+\z/)
      self.department_number = stripped
      return
    end

    numeric = stripped.to_i
    return if numeric.negative? || numeric > 999

    self.department_number = format("%03d", numeric)
  end
end
