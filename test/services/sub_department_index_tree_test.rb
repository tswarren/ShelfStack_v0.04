# frozen_string_literal: true

require "test_helper"

class SubDepartmentIndexTreeTest < ActiveSupport::TestCase
  test "orders departments by department number with subdepartments nested below" do
    dept_b = create_department!(department_number: "020", name: "Dept B", short_name: "DeptB")
    dept_a = create_department!(department_number: "010", name: "Dept A", short_name: "DeptA")
    tax_category = create_tax_category!
    sub_b = create_sub_department!(department: dept_b, name: "Sub B", short_name: "SubB", default_tax_category: tax_category)
    sub_a = create_sub_department!(department: dept_a, name: "Sub A", short_name: "SubA", default_tax_category: tax_category)

    rows = SubDepartmentIndexTree.rows
    relevant_department_ids = [ dept_a.id, dept_b.id ]
    scoped_rows = rows.select do |row|
      case row.record
      when Department
        relevant_department_ids.include?(row.record.id)
      when SubDepartment
        relevant_department_ids.include?(row.record.department_id)
      else
        false
      end
    end

    assert_equal [ :department, :sub_department, :department, :sub_department ], scoped_rows.map(&:record_type)
    assert_equal [ dept_a, sub_a, dept_b, sub_b ], scoped_rows.map(&:record)
    assert_equal [ 0, 1, 0, 1 ], scoped_rows.map(&:depth)
  end
end
