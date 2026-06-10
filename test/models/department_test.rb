# frozen_string_literal: true

require "test_helper"

class DepartmentTest < ActiveSupport::TestCase
  test "valid department" do
    department = Department.new(
      department_number: "001",
      name: "Books",
      short_name: "Books"
    )
    assert department.valid?
    assert department.save
  end

  test "department number normalizes to three digits" do
    {
      "1" => "001",
      "2" => "002",
      "10" => "010",
      "25" => "025",
      "100" => "100"
    }.each do |input, expected|
      department = Department.new(
        department_number: input,
        name: "Dept #{input}",
        short_name: "D#{input}"
      )
      department.valid?
      assert_equal expected, department.department_number, "expected #{input} to normalize to #{expected}"
    end
  end

  test "invalid department number is rejected" do
    %w[A10 1.5 1000 -1].each do |invalid|
      department = Department.new(
        department_number: invalid,
        name: "Invalid #{invalid}",
        short_name: "Inv#{invalid.tr('.', '')}"
      )
      assert_not department.valid?, "expected #{invalid} to be invalid"
    end
  end

  test "duplicate department number is rejected" do
    Department.create!(department_number: "001", name: "Books", short_name: "Books")

    duplicate = Department.new(department_number: "001", name: "Other", short_name: "Other")
    assert_not duplicate.valid?
  end
end
