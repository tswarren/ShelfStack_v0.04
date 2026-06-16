# frozen_string_literal: true

require "test_helper"

class ProductConditionTest < ActiveSupport::TestCase
  test "condition key must be unique" do
    create_product_condition!(condition_key: "unique_key")
    duplicate = ProductCondition.new(
      condition_key: "unique_key",
      name: "Dup",
      short_name: "Dup Short",
      active: true
    )
    assert_not duplicate.valid?
  end

  test "sku component normalized to uppercase" do
    condition = create_product_condition!(condition_key: "signed", sku_component: "sg", short_name: "Signed")
    assert_equal "SG", condition.sku_component
  end

  test "default list price factor must be within range" do
    condition = build_condition(default_list_price_factor_bps: 10_001)
    assert_not condition.valid?
  end

  private

  def build_condition(**attrs)
    ProductCondition.new({
      condition_key: "test",
      name: "Test",
      short_name: "Test",
      active: true
    }.merge(attrs))
  end
end
