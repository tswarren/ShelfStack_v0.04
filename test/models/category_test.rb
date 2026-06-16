# frozen_string_literal: true

require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  setup do
    @department = Department.create!(department_number: "001", name: "Books", short_name: "Books")
    @tax_category = TaxCategory.create!(name: "Books", short_name: "Books", sort_order: 10)
  end

  test "valid category" do
    category = Category.new(
      department: @department,
      name: "Hardcover",
      short_name: "Hardcover",
      default_tax_category: @tax_category,
      default_pricing_model: "trade_discount",
      default_margin_target_bps: 4000
    )
    assert category.valid?
    assert category.save
  end

  test "name and short_name unique within department" do
    Category.create!(
      department: @department,
      name: "Hardcover",
      short_name: "Hardcover",
      default_tax_category: @tax_category
    )

    duplicate = Category.new(
      department: @department,
      name: "Hardcover",
      short_name: "HC",
      default_tax_category: @tax_category
    )
    assert_not duplicate.valid?

    other_dept = Department.create!(department_number: "002", name: "Periodicals", short_name: "Periodicals")
    other = Category.new(
      department: other_dept,
      name: "Hardcover",
      short_name: "Hardcover",
      default_tax_category: @tax_category
    )
    assert other.valid?
  end

  test "rejects invalid pricing model" do
    category = Category.new(
      department: @department,
      name: "Bad",
      short_name: "Bad",
      default_tax_category: @tax_category,
      default_pricing_model: "invalid_model"
    )
    assert_not category.valid?
  end

  test "rejects inactive department" do
    @department.update!(active: false)

    category = Category.new(
      department: @department,
      name: "Hardcover",
      short_name: "Hardcover",
      default_tax_category: @tax_category
    )
    assert_not category.valid?
    assert_includes category.errors[:department], "must be active"
  end

  test "rejects inactive default tax category" do
    @tax_category.update!(active: false)

    category = Category.new(
      department: @department,
      name: "Hardcover",
      short_name: "Hardcover",
      default_tax_category: @tax_category
    )
    assert_not category.valid?
    assert_includes category.errors[:default_tax_category], "must be active"
  end

  test "rejects subdepartment from a different department" do
    other_department = Department.create!(department_number: "004", name: "Used Books", short_name: "Used")
    sub_department = create_sub_department!(
      department: other_department,
      sub_department_key: "used_books_test",
      name: "Used Books Test",
      short_name: "Used Test"
    )

    category = Category.new(
      department: @department,
      name: "Mismatch",
      short_name: "Mismatch",
      default_tax_category: @tax_category,
      sub_department: sub_department
    )

    assert_not category.valid?
    assert_includes category.errors[:sub_department], "must belong to the same department"
  end
end
