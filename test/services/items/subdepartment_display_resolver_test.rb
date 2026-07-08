# frozen_string_literal: true

require "test_helper"

class Items::SubdepartmentDisplayResolverTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase3bTestHelper

  setup do
    @product = create_product!
    @variant = create_product_variant!(product: @product)
    @sub_department = @variant.sub_department
  end

  test "prefers variant sub_department" do
    result = Items::SubdepartmentDisplayResolver.for(variant: @variant, product: @product)

    assert_equal @sub_department, result.sub_department
    assert_equal "variant", result.source
  end

  test "falls back to product default sub_department" do
    fallback = create_sub_department!(sub_department_key: "fallback-#{SecureRandom.hex(3)}", name: "Fallback Dept")
    @product.update!(default_sub_department: fallback, store_category: nil)
    variant = Struct.new(:sub_department, :product).new(nil, @product)

    result = Items::SubdepartmentDisplayResolver.for(variant: variant, product: @product)

    assert_equal fallback, result.sub_department
    assert_equal "product", result.source
  end

  test "falls back to store category default sub_department" do
    store_category = create_category_node!(
      category_scheme: create_category_scheme!(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY, name: "Store Sections"),
      node_key: "sc-#{SecureRandom.hex(3)}",
      name: "Children"
    )
    category_default = create_sub_department!(sub_department_key: "cat-#{SecureRandom.hex(3)}", name: "Children Books")
    store_category.update!(default_sub_department: category_default)
    @product.update!(store_category: store_category, default_sub_department: nil)
    variant = Struct.new(:sub_department, :product).new(nil, @product)

    result = Items::SubdepartmentDisplayResolver.for(variant: variant, product: @product)

    assert_equal category_default, result.sub_department
    assert_equal "store_category", result.source
  end

  test "returns none when no subdepartment can be resolved" do
    @product.update!(default_sub_department: nil, store_category: nil)
    variant = Struct.new(:sub_department, :product).new(nil, @product)

    result = Items::SubdepartmentDisplayResolver.for(variant: variant, product: @product)

    assert_nil result.sub_department
    assert_equal "none", result.source
  end
end
