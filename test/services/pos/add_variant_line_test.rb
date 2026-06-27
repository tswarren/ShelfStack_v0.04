# frozen_string_literal: true

require "test_helper"

class Pos::AddVariantLineTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(selling_price_cents: 1500)
    @transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @user)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
  end

  test "return_no_receipt entry action creates negative quantity line" do
    line = Pos::AddVariantLine.call!(
      transaction: @transaction,
      variant: @variant,
      entry_action: "return_no_receipt"
    )

    assert_equal(-1, line.quantity)
    assert_equal "return_to_stock", line.return_disposition
  end
end
