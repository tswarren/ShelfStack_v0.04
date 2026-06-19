# frozen_string_literal: true

require "test_helper"

class Pos::ReturnLookupTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(selling_price_cents: 1500)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)

    @sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{ product_variant: @variant, quantity: 2, unit_price_cents: 1500, extended_price_cents: 3000 }]
    )
    complete_pos_sale!(transaction: @sale, user: @user, register_session: @register_session)
    @source_line = @sale.pos_transaction_lines.first
  end

  test "fully returned sale line is not returnable" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{
        product_variant: @variant,
        quantity: -2,
        unit_price_cents: 1500,
        extended_price_cents: -3000,
        return_disposition: "return_to_stock",
        source_transaction: @sale,
        source_transaction_line_id: @source_line.id
      }]
    )
    complete_pos_sale!(transaction: return_txn, user: @user, register_session: @register_session)

    result = Pos::ReturnLookup.call(
      store: @store,
      transaction_number: @sale.transaction_number
    )

    assert_equal :found, result.status
    line = result.lines.sole
    assert_equal 2, line[:sold_quantity]
    assert_equal 2, line[:returned_quantity]
    assert_equal 0, line[:remaining_quantity]
    refute line[:returnable]
  end

  test "partially returned sale line shows remaining quantity" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{
        product_variant: @variant,
        quantity: -1,
        unit_price_cents: 1500,
        extended_price_cents: -1500,
        return_disposition: "return_to_stock",
        source_transaction: @sale,
        source_transaction_line_id: @source_line.id
      }]
    )
    complete_pos_sale!(transaction: return_txn, user: @user, register_session: @register_session)

    result = Pos::ReturnLookup.call(
      store: @store,
      transaction_number: @sale.transaction_number
    )

    line = result.lines.sole
    assert_equal 1, line[:returned_quantity]
    assert_equal 1, line[:remaining_quantity]
    assert line[:returnable]
  end

  test "return receipt resolves to original sale and hides fully returned lines" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{
        product_variant: @variant,
        quantity: -1,
        unit_price_cents: 1500,
        extended_price_cents: -1500,
        return_disposition: "return_to_stock",
        source_transaction: @sale,
        source_transaction_line_id: @source_line.id
      }]
    )
    complete_pos_sale!(transaction: return_txn, user: @user, register_session: @register_session)

    result = Pos::ReturnLookup.call(
      store: @store,
      transaction_number: return_txn.transaction_number
    )

    assert_equal :found, result.status
    assert_equal @sale.transaction_number, result.transaction.transaction_number
    assert_match @sale.transaction_number, result.message

    line = result.lines.sole
    assert_equal 1, line[:returned_quantity]
    assert_equal 1, line[:remaining_quantity]
    assert line[:returnable]
  end

  test "return receipt with fully returned sale line offers no returnable lines" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{
        product_variant: @variant,
        quantity: -2,
        unit_price_cents: 1500,
        extended_price_cents: -3000,
        return_disposition: "return_to_stock",
        source_transaction: @sale,
        source_transaction_line_id: @source_line.id
      }]
    )
    complete_pos_sale!(transaction: return_txn, user: @user, register_session: @register_session)

    result = Pos::ReturnLookup.call(
      store: @store,
      transaction_number: return_txn.transaction_number
    )

    assert_equal :found, result.status
    assert_equal @sale.transaction_number, result.transaction.transaction_number
    line = result.lines.sole
    refute line[:returnable]
  end

  test "only sale lines are offered from mixed exchange receipt" do
    other_variant = create_product_variant!(
      sku: "POS-RETURN-OTHER",
      selling_price_cents: 1000,
      sub_department: @variant.sub_department
    )

    exchange = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        {
          product_variant: other_variant,
          quantity: 1,
          unit_price_cents: 1000,
          extended_price_cents: 1000
        },
        {
          product_variant: @variant,
          quantity: -1,
          unit_price_cents: 1500,
          extended_price_cents: -1500,
          return_disposition: "return_to_stock",
          source_transaction: @sale,
          source_transaction_line_id: @source_line.id
        }
      ]
    )
    complete_pos_sale!(transaction: exchange, user: @user, register_session: @register_session)

    result = Pos::ReturnLookup.call(
      store: @store,
      transaction_number: exchange.transaction_number
    )

    assert_equal 1, result.lines.size
    assert_equal other_variant.sku, result.lines.first[:sku]
    assert result.lines.first[:returnable]
  end
end
