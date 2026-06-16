# frozen_string_literal: true

class SubDepartmentIndexTree
  Row = Data.define(:record, :depth, :record_type)

  def self.rows
    new.rows
  end

  def rows
    sub_departments_by_department = SubDepartment
      .includes(:default_tax_category, :department)
      .order(:name)
      .group_by(&:department_id)

    ordered = []
    Department.order(:department_number, :name).each do |department|
      ordered << Row.new(record: department, depth: 0, record_type: :department)
      Array(sub_departments_by_department[department.id])
        .sort_by { |sub_department| sub_department.name.to_s.downcase }
        .each do |sub_department|
          ordered << Row.new(record: sub_department, depth: 1, record_type: :sub_department)
        end
    end

    ordered
  end
end
