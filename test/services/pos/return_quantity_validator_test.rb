# frozen_string_literal: true

require "test_helper"

class Pos::ReturnQuantityValidatorTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(selling_price_cents: 1000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)

    @sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 2, unit_price_cents: 1000, extended_price_cents: 2000 } ]
    )
    complete_pos_sale!(transaction: @sale, user: @user, register_session: @register_session)
    @source_line = @sale.pos_transaction_lines.first
  end

  test "blocks cumulative returns above sold quantity" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ {
        product_variant: @variant,
        quantity: -2,
        unit_price_cents: 1000,
        extended_price_cents: -2000,
        return_disposition: "return_to_stock",
        source_transaction_line_id: @source_line.id
      } ]
    )
    complete_pos_sale!(transaction: return_txn, user: @user, register_session: @register_session)

    excess = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ {
        product_variant: @variant,
        quantity: -1,
        unit_price_cents: 1000,
        extended_price_cents: -1000,
        return_disposition: "return_to_stock",
        source_transaction_line_id: @source_line.id
      } ]
    )

    assert_raises(Pos::ReturnQuantityValidator::Error) do
      Pos::ReturnQuantityValidator.call!(excess.pos_transaction_lines.first)
    end
  end
end
