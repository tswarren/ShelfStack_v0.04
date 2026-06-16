# frozen_string_literal: true

require "test_helper"

class SubDepartmentTest < ActiveSupport::TestCase
  test "requires stable key, department, and active tax category" do
    tax_category = create_tax_category!
    department = create_department!
    sub_department = SubDepartment.new(
      sub_department_key: "general_trade_books",
      name: "General Trade Books",
      short_name: "Trade Books",
      department: department,
      default_tax_category: tax_category
    )

    assert sub_department.valid?
    assert sub_department.save
  end

  test "normalizes merchandise class key" do
    tax_category = create_tax_category!
    sub_department = create_sub_department!(
      sub_department_key: " TEST_KEY ",
      default_tax_category: tax_category
    )

    assert_equal "test_key", sub_department.sub_department_key
  end
end
