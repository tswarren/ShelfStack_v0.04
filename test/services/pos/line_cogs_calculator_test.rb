# frozen_string_literal: true

require "test_helper"

class Pos::LineCogsCalculatorTest < ActiveSupport::TestCase
  include Phase6TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase6_permissions!(@user, store: @store)
    @variant = create_product_variant!(selling_price_cents: 2000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
  end

  test "sale uses pre-sale moving average" do
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 5, unit_cost_cents: 800)
    line = build_line(product_variant: @variant, quantity: 1, unit_price_cents: 2000, extended_price_cents: 2000)

    result = Pos::LineCogsCalculator.call(line: line, store: @store)

    assert_equal 800, result.unit_cogs_cents
    assert_equal 800, result.total_cogs_cents
    assert_equal "moving_average", result.cogs_source
    assert_equal "merchandise", result.revenue_treatment
    assert_not result.cogs_estimated
  end

  test "sale uses unit cost when moving average is absent" do
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 2, unit_cost_cents: 800)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    balance.update_columns(moving_average_unit_cost_cents: nil, unit_cost_cents: 800)

    line = build_line(product_variant: @variant, quantity: 1, unit_price_cents: 2000, extended_price_cents: 2000)
    result = Pos::LineCogsCalculator.call(line: line, store: @store)

    assert_equal 800, result.unit_cogs_cents
    assert_equal "unit_cost", result.cogs_source
    assert_equal "unit_cost", result.costing_method_snapshot
    assert_not result.cogs_estimated
  end

  test "non-inventory variant has null cogs" do
    @variant.update!(inventory_behavior: "digital_asset")
    line = build_line(product_variant: @variant, quantity: 1, unit_price_cents: 2000, extended_price_cents: 2000)

    result = Pos::LineCogsCalculator.call(line: line, store: @store)

    assert_nil result.unit_cogs_cents
    assert_nil result.total_cogs_cents
    assert_equal "none", result.cogs_source
    assert_equal "none", result.revenue_treatment
  end

  test "financial non-inventory variant uses liability revenue treatment" do
    @variant.product.update!(product_type: "financial")
    @variant.update!(inventory_behavior: "digital_asset")
    line = build_line(product_variant: @variant, quantity: 1, unit_price_cents: 2000, extended_price_cents: 2000)

    result = Pos::LineCogsCalculator.call(line: line, store: @store)

    assert_equal "liability", result.revenue_treatment
  end

  test "sourced return reverses source cogs when variant is now non-inventory" do
    sale = complete_sale_line!(quantity: 1)
    source_line = sale.pos_transaction_lines.first
    @variant.update!(inventory_behavior: "digital_asset")

    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        {
          product_variant: @variant,
          quantity: -1,
          unit_price_cents: 2000,
          extended_price_cents: 2000,
          source_transaction_line_id: source_line.id
        }
      ]
    )
    return_line = return_txn.pos_transaction_lines.first

    result = Pos::LineCogsCalculator.call(line: return_line, store: @store)

    assert_equal source_line.unit_cogs_cents, result.unit_cogs_cents
    assert_equal(-source_line.unit_cogs_cents, result.total_cogs_cents)
    assert_equal "return_reversal", result.cogs_source
    assert_not result.cogs_estimated
  end

  test "return reverses source cogs with signed total" do
    sale = complete_sale_line!(quantity: 1)
    source_line = sale.pos_transaction_lines.first

    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        {
          product_variant: @variant,
          quantity: -1,
          unit_price_cents: 2000,
          extended_price_cents: -2000,
          source_transaction_line_id: source_line.id
        }
      ]
    )
    return_line = return_txn.pos_transaction_lines.first

    result = Pos::LineCogsCalculator.call(line: return_line, store: @store)

    assert_equal source_line.unit_cogs_cents, result.unit_cogs_cents
    assert_equal(-source_line.unit_cogs_cents, result.total_cogs_cents)
    assert_equal "return_reversal", result.cogs_source
    assert_not result.cogs_estimated
  end

  test "blind return uses estimated fallback" do
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 2, unit_cost_cents: 600)
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: -1, unit_price_cents: 2000, extended_price_cents: -2000 } ]
    )
    return_line = return_txn.pos_transaction_lines.first

    result = Pos::LineCogsCalculator.call(line: return_line, store: @store)

    assert result.cogs_estimated
    assert_equal(-600, result.total_cogs_cents)
  end

  test "open ring uses margin estimate and flags estimated" do
    sub = @variant.sub_department
    sub.update!(default_margin_target_bps: 4000)
    line = build_line(line_type: "open_ring", product_variant: nil, sub_department: sub, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000)

    result = Pos::LineCogsCalculator.call(line: line, store: @store)

    assert_equal 600, result.unit_cogs_cents
    assert result.cogs_estimated
    assert_equal "service", result.revenue_treatment
  end

  private

  def build_line(**attrs)
    txn = create_pos_transaction!(store: @store, workstation: @workstation, user: @user)
    txn.pos_transaction_lines.create!({ line_number: 1, line_type: "variant" }.merge(attrs))
  end

  def complete_sale_line!(quantity:)
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: quantity, unit_price_cents: 2000, extended_price_cents: 2000 * quantity } ]
    )
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 5, unit_cost_cents: 800)
    complete_pos_sale!(transaction: transaction, user: @user, register_session: @register_session)
    transaction.reload
  end
end
