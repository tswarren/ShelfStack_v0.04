# frozen_string_literal: true

require "test_helper"

class TaxCategoryTest < ActiveSupport::TestCase
  test "valid tax category" do
    category = TaxCategory.new(name: "Books", short_name: "Books", sort_order: 10)
    assert category.valid?
    assert category.save
    assert category.active?
  end

  test "name and short_name must be unique" do
    TaxCategory.create!(name: "Books", short_name: "Books", sort_order: 10)

    duplicate = TaxCategory.new(name: "Books", short_name: "Bk", sort_order: 20)
    assert_not duplicate.valid?

    duplicate2 = TaxCategory.new(name: "Book Tax", short_name: "Books", sort_order: 20)
    assert_not duplicate2.valid?
  end

  test "strips whitespace from names" do
    category = TaxCategory.create!(name: "  Books  ", short_name: "  Bk  ", sort_order: 10)
    assert_equal "Books", category.name
    assert_equal "Bk", category.short_name
  end
end
