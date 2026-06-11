# frozen_string_literal: true

require "test_helper"

class MerchandiseClassTest < ActiveSupport::TestCase
  test "requires stable key and active tax category" do
    tax_category = create_tax_category!
    merchandise_class = MerchandiseClass.new(
      merchandise_class_key: "general_trade_books",
      name: "General Trade Books",
      short_name: "Trade Books",
      default_tax_category: tax_category
    )

    assert merchandise_class.valid?
    assert merchandise_class.save
  end

  test "normalizes merchandise class key" do
    tax_category = create_tax_category!
    merchandise_class = create_merchandise_class!(
      merchandise_class_key: " TEST_KEY ",
      default_tax_category: tax_category
    )

    assert_equal "test_key", merchandise_class.merchandise_class_key
  end
end
