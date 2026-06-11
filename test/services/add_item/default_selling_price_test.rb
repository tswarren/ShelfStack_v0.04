# frozen_string_literal: true

require "test_helper"

class AddItemDefaultSellingPriceTest < ActiveSupport::TestCase
  include Phase3TestHelper

  test "conditional price uses condition factor" do
    product = create_product!(list_price_cents: 2000, variation_type: "conditional")
    condition = create_product_condition!(default_list_price_factor_bps: 5000)

    assert_equal 1000, AddItem::DefaultSellingPrice.cents(product: product, condition: condition)
  end

  test "standard variation uses list price" do
    product = create_product!(list_price_cents: 2000, variation_type: "standard")

    assert_equal 2000, AddItem::DefaultSellingPrice.cents(product: product, condition: nil)
  end
end
