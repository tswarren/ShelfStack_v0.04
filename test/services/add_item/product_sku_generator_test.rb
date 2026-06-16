# frozen_string_literal: true

require "test_helper"

class AddItemProductSkuGeneratorTest < ActiveSupport::TestCase
  include Phase3TestHelper

  test "generate returns unique product sku" do
    sku = AddItem::ProductSkuGenerator.generate!
    assert_match(/\AP\d{8}\z/, sku)
    assert_not Product.exists?(sku: sku)
  end
end
