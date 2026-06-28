# frozen_string_literal: true

require "test_helper"

class Pos::SettlementInputParserTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(selling_price_cents: 1500)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        {
          product_variant: @variant,
          quantity: -1,
          unit_price_cents: 1500,
          extended_price_cents: -1500,
          return_disposition: "return_to_stock"
        }
      ]
    )
    Pos::RecalculateTransaction.call!(@transaction)
  end

  test "normalizes stored_value placeholder to store_credit on refund" do
    rows = Pos::SettlementInputParser.parse(
      transaction: @transaction,
      raw_inputs: [
        { tender_type: "stored_value", amount_cents: @transaction.total_cents, generate_identifier: true }
      ]
    )

    assert_equal 1, rows.size
    assert_equal "store_credit", rows.first.tender_type
    assert rows.first.generate_identifier
  end

  test "leaves stored_value placeholder unchanged on sale transaction" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        {
          product_variant: @variant,
          quantity: 1,
          unit_price_cents: 1500,
          extended_price_cents: 1500
        }
      ]
    )
    Pos::RecalculateTransaction.call!(sale)

    rows = Pos::SettlementInputParser.parse(
      transaction: sale,
      raw_inputs: [ { tender_type: "stored_value", amount_cents: sale.total_cents } ]
    )

    assert_equal "stored_value", rows.first.tender_type
    refute rows.first.generate_identifier
  end
end
